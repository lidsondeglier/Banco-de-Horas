# Sistema de Horas Extras: como colocar no ar

Você vai usar dois serviços gratuitos: **Supabase** (banco de dados e login) e **Netlify** (para publicar o site).

## 1. Criar o banco (Supabase)
1. Entre em supabase.com, crie uma conta e clique em **New project**. Escolha um nome, defina uma senha do banco (guarde-a) e a região **South America (São Paulo)**.
2. Quando o projeto terminar de carregar, abra **SQL Editor** > **New query**.
3. Abra o arquivo `setup.sql`, copie todo o conteúdo, cole no editor e clique em **Run**. Deve aparecer "Success".

## 2. Copiar as chaves
1. Vá em **Project Settings** > **API**.
2. Copie a **Project URL** e a chave **anon public**.
3. Abra o `index.html` em um editor de texto (Bloco de Notas serve) e substitua, no início do script:
   - `COLE_AQUI_A_PROJECT_URL` pela Project URL
   - `COLE_AQUI_A_ANON_PUBLIC_KEY` pela chave anon public
4. Salve. Nunca use a chave `service_role` no arquivo.

## 3. Criar o administrador
1. No Supabase, vá em **Authentication** > **Users** > **Add user** > **Create new user**.
2. Informe e-mail e senha e **marque "Auto Confirm User"**.
3. Em **SQL Editor**, rode (trocando pelo e-mail do administrador):
   ```sql
   update profiles set role='admin', nome='Seu Nome' where id=(select id from auth.users where email='admin@exemplo.com');
   ```
   Repita para cada administrador.

## 4. Cadastrar funcionários
Para cada funcionário: **Authentication** > **Users** > **Add user** > **Create new user**, com e-mail, senha e "Auto Confirm User" marcado. Ele aparece na aba **Equipe** do sistema, onde você pode editar o nome ou desativar.
Para trocar a senha de alguém, use o mesmo painel (menu do usuário > Send password recovery ou editar a senha).
Se a pessoa não tem e-mail, você pode usar um fictício, por exemplo `joao@smo.local`.

## 5. Publicar o site (Netlify)
1. Entre em app.netlify.com/drop (o endereço permite arrastar arquivos).
2. Arraste a **pasta** que contém o `index.html` já editado.
3. O Netlify gera um link. Envie esse link aos funcionários. No celular, pode usar **Adicionar à tela inicial**.

## Antes de usar de verdade
- Teste com 1 administrador e 2 funcionários: envie, aprove, rejeite, peça correção, e confira que um funcionário não vê os registros do outro.
- Em **Authentication** > **Sign In / Providers**, desative **Allow new users to sign up** para ninguém se cadastrar sozinho.
- O plano gratuito do Supabase pausa o projeto após cerca de uma semana sem acesso; no uso diário isso não acontece.
