# Backup

Backup diário pra um bucket S3 usando [restic](https://restic.net/), rodando via Docker pra não
precisar instalar nada no host. Criptografado no cliente antes de sair da VPS.

## O que é coberto

- Banco Postgres `recompra_farma`: um dump lógico `pg_dump -Fc` (não os arquivos de dados brutos)
  feito na hora em cada execução, então o backup é sempre uma cópia consistente de um ponto no tempo.
- Volume de dados do Redis, depois de um `BGSAVE` pra gerar um snapshot RDB atualizado.
- Volume de instância do Evolution API (dados de sessão do WhatsApp).
- O resto de `/home/<usuario>`: código e configs de projetos que não estão em um remote git,
  arquivos `.env`, credenciais do Cloudflare Tunnel, chaves SSH.
- Excluído (ver `restic-excludes.txt`): `node_modules`, `.git`, build output, caches locais, e
  output de pipeline gerado que é barato de regerar. Ajuste o arquivo de exclusão se isso não
  fizer sentido pro seu caso.

## Configuração

1. Crie um bucket S3 e um usuário IAM restrito (ver os passos "S3 + IAM" abaixo).
2. `cp .env.example .env`, preencha `RESTIC_REPOSITORY`, `RESTIC_PASSWORD` e as chaves AWS.
   `chmod 600 .env`. Guarde o `RESTIC_PASSWORD` também num gerenciador de senhas — sem ele os
   backups no S3 são só ruído criptografado.
3. Rode `./restic-backup.sh` uma vez manualmente pra confirmar que funciona de ponta a ponta.
4. Agende (não precisa de root, é o crontab do próprio usuário que invoca):
   ```
   crontab -e
   # adicione:
   0 4 * * * /home/<usuario>/backup/restic-backup.sh >> /home/<usuario>/backup/backup.log 2>&1
   ```

## Restaurando

Listar snapshots:
```bash
docker run --rm -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
  restic/restic:latest snapshots
```
(exporte as mesmas quatro variáveis do `.env`, ou rode com `--env-file .env`)

Restaurar tudo do último snapshot pra um diretório temporário:
```bash
docker run --rm -e RESTIC_REPOSITORY -e RESTIC_PASSWORD -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
  -v /caminho/para/restaurar:/restore \
  restic/restic:latest restore latest --target /restore
```

Restaurar só o dump do Postgres:
```bash
... restic/restic:latest restore latest --target /restore --include /data/pg-dumps
```
depois `docker exec -i farma-postgres pg_restore -U farma -d recompra_farma --clean < recompra_farma.dump`.

## Bucket S3 + IAM (feito uma vez, no console da AWS)

1. Crie um bucket (ex: `sa-east-1`), mantenha "Block all public access" ligado, ative versionamento.
2. Crie uma policy IAM restrita a esse bucket (`ListBucket`, `GetObject`, `PutObject`,
   `DeleteObject`, `GetObjectVersion`, `DeleteObjectVersion` em `arn:aws:s3:::seu-bucket` e
   `arn:aws:s3:::seu-bucket/*`).
3. Crie um usuário IAM com acesso só programático, anexe essa policy, gere uma access key.

Restringir a policy a um único bucket significa que uma chave vazada só consegue mexer nos dados
de backup, nada mais na conta AWS.
