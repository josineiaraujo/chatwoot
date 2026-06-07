# Imagem Docker privada Ibsoft

Este projeto publica uma imagem privada do Chatwoot customizado no GitHub
Container Registry:

```text
ghcr.io/josineiaraujo/chathub-chatwoot:ibsoft-production
```

## Publicacao

Use o workflow `Publish Ibsoft Chatwoot EE Docker image`.

Modos recomendados:

- Push na branch `ibsoft/production`: publica a tag `ibsoft-production`.
- Push de uma tag `ibsoft-image-*`: publica uma imagem com o nome da tag,
  removendo o prefixo `ibsoft-image-`.
- Execucao manual pelo GitHub: publica a tag informada em `image_tag`.

Entradas recomendadas para execucao manual:

- `image_tag`: `ibsoft-production`
- `platforms`: `linux/amd64`

O workflow sempre publica tambem uma tag imutavel no formato `sha-<commit>`.

O workflow usa `GITHUB_TOKEN`, portanto nao e necessario criar token manual
para publicar a partir do proprio repositorio.

Importante: o botao manual `workflow_dispatch` do GitHub so aparece quando o
arquivo do workflow esta na branch padrao do repositorio. Como a `develop` deve
ficar alinhada ao Chatwoot oficial, prefira publicar por push em
`ibsoft/production` ou por tag `ibsoft-image-*`.

Exemplo de publicacao por tag a partir da branch atual:

```sh
git tag ibsoft-image-teste-20260607
git push origin ibsoft-image-teste-20260607
```

## Privacidade e acesso

Apos a primeira publicacao, confira a visibilidade do pacote em GitHub Packages.
O pacote deve permanecer privado.

Para outra pessoa ou servidor baixar a imagem, essa identidade precisa ter
permissao de leitura no pacote e autenticar no GHCR:

```sh
docker login ghcr.io -u USUARIO_GITHUB
docker pull ghcr.io/josineiaraujo/chathub-chatwoot:ibsoft-production
```

Use um token do GitHub com permissao de leitura de pacotes quando a conta nao
tiver acesso direto por sessao interativa.

## Uso com Docker Compose

O arquivo `docker-compose.ibsoft.production.yaml` sobrescreve apenas a imagem
dos servicos `base`, `rails` e `sidekiq`.

Exemplo:

```sh
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.ibsoft.production.yaml \
  pull

docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.ibsoft.production.yaml \
  up -d
```

As variaveis continuam vindo do `.env` do ambiente onde o compose sera
executado. Nao inclua `.env`, backups ou segredos na imagem.

## Edicao Enterprise

A imagem privada Ibsoft e gerada como Chatwoot EE:

```dockerfile
ENV CW_EDITION="ee"
```

Ela mantem a pasta `enterprise` dentro da imagem, seguindo o padrao do workflow
oficial `publish_ee_docker.yml` do Chatwoot.

Isso permite usar a mesma imagem privada com os recursos Enterprise quando a
instalacao tiver licenca/plano valido. As customizacoes Ibsoft continuam na
mesma imagem.

## Observacoes

- A imagem e gerada como Chatwoot EE, seguindo o padrao oficial do projeto.
- A publicacao local `linux/amd64` em Mac Apple Silicon pode falhar por
  emulacao durante o build dos assets. Para producao, prefira o workflow em
  runner `ubuntu-latest`, que gera `linux/amd64` nativamente.
- Para servidores ARM, execute o workflow com `platforms` definido como
  `linux/arm64` ou publique uma tag separada.
