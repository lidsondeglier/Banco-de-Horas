-- SISTEMA DE HORAS EXTRAS - configuração do banco (Supabase)
-- Cole tudo no SQL Editor do Supabase e clique em RUN.

create table profiles(
  id uuid primary key references auth.users on delete cascade,
  nome text not null default '',
  role text not null default 'funcionario' check (role in ('admin','funcionario')),
  ativo boolean not null default true,
  criado_em timestamptz default now());

create function is_admin() returns boolean language sql security definer stable set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='admin' and ativo) $$;
create function is_ativo() returns boolean language sql security definer stable set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and ativo) $$;

-- cria o perfil automaticamente quando você cadastra um usuário
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as
$$ begin
  insert into profiles(id,nome) values(new.id, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)));
  return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

create table overtime(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id),
  data date not null,
  ini time not null, fim time not null,
  pausa text not null check (pausa in ('com','sem')),
  saida time, volta time,
  obs text default '',
  minutos int not null default 0,
  tipo text not null default 'util',   -- util, sabado, domingo, nacional, estadual, municipal, facultativo
  feriado text default '',
  status text not null default 'pendente' check (status in ('pendente','aprovado','rejeitado','correcao')),
  rev int not null default 1,
  pedido text default '',
  nota text default '',
  decidido_por uuid references profiles(id),
  decidido_em timestamptz,
  criado_em timestamptz default now());

create table overtime_log(
  id bigserial primary key,
  overtime_id uuid not null references overtime(id),
  por uuid default auth.uid(),
  acao text not null, nota text default '',
  em timestamptz default now());

create table holidays(
  id bigserial primary key,
  data date not null unique,
  nome text not null,
  tipo text not null check (tipo in ('nacional','estadual','municipal','facultativo')));

-- Regras de segurança do registro: o banco impõe, não só a tela
create function ot_guard() returns trigger language plpgsql security definer set search_path=public as
$$ declare r overtime; t int; p int;
begin
  if tg_op='INSERT' then
    new.user_id:=auth.uid(); new.status:='pendente'; new.rev:=1; new.nota:=''; new.pedido:='';
    new.decidido_por:=null; new.decidido_em:=null;
  elsif is_admin() then
    if old.user_id=auth.uid() then raise exception 'Você não pode decidir as próprias horas'; end if;
    r:=new; new:=old; new.status:=r.status; new.nota:=coalesce(r.nota,'');
    new.decidido_por:=auth.uid(); new.decidido_em:=now(); return new;
  else
    if old.user_id<>auth.uid() then raise exception 'Sem permissão'; end if;
    r:=new; new:=old;
    if r.status=old.status then
      new.pedido:=coalesce(r.pedido,''); return new;   -- só pode pedir alteração
    elsif old.status='correcao' and r.status='pendente' then
      new:=r; new.user_id:=old.user_id; new.status:='pendente'; new.rev:=old.rev+1; new.pedido:='';
      new.nota:=old.nota; new.decidido_por:=old.decidido_por; new.decidido_em:=old.decidido_em;
    else raise exception 'Registro já enviado. Solicite a alteração ao administrador.'; end if;
  end if;
  -- recalcula as horas no servidor (descontando o almoço)
  t:=extract(epoch from (new.fim-new.ini))/60; if t<=0 then t:=t+1440; end if;
  if new.pausa='com' then
    if new.saida is null or new.volta is null then raise exception 'Informe saída e retorno do almoço'; end if;
    p:=extract(epoch from (new.volta-new.saida))/60; if p<0 then p:=p+1440; end if; t:=t-p;
  else new.saida:=null; new.volta:=null; end if;
  if t<=0 then raise exception 'Horário inválido'; end if;
  new.minutos:=t; return new;
end $$;
create trigger ot_guard_t before insert or update on overtime for each row execute function ot_guard();

create function ot_log() returns trigger language plpgsql security definer set search_path=public as
$$ begin
  if tg_op='INSERT' then insert into overtime_log(overtime_id,acao) values(new.id,'enviado');
  elsif new.status<>old.status then insert into overtime_log(overtime_id,acao,nota) values(new.id,new.status,coalesce(new.nota,''));
  elsif new.pedido<>old.pedido then insert into overtime_log(overtime_id,acao,nota) values(new.id,'pedido_alteracao',new.pedido);
  end if; return new; end $$;
create trigger ot_log_t after insert or update on overtime for each row execute function ot_log();

-- Permissões (RLS)
alter table profiles enable row level security;
alter table overtime enable row level security;
alter table overtime_log enable row level security;
alter table holidays enable row level security;

create policy p_sel on profiles for select to authenticated using (true);
create policy p_upd on profiles for update to authenticated using (is_admin()) with check (is_admin());

create policy o_sel on overtime for select to authenticated using ((user_id=auth.uid() and is_ativo()) or is_admin());
create policy o_ins on overtime for insert to authenticated with check (user_id=auth.uid() and is_ativo());
create policy o_upd on overtime for update to authenticated using ((user_id=auth.uid() and is_ativo()) or is_admin()) with check ((user_id=auth.uid() and is_ativo()) or is_admin());

create policy l_sel on overtime_log for select to authenticated using (is_admin() or exists(select 1 from overtime o where o.id=overtime_id and o.user_id=auth.uid()));

create policy h_sel on holidays for select to authenticated using (true);
create policy h_all on holidays for all to authenticated using (is_admin()) with check (is_admin());

-- Tempo real
alter publication supabase_realtime add table overtime, holidays, profiles;
