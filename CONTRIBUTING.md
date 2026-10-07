# Contributing

Create branches from `develop`, keep changes small, and open pull requests into `develop`. Changes promoted to production go from `develop` to `main` through a reviewed pull request.

Before opening a PR run:

```bash
make lint
make test
terraform fmt -recursive -check infra
helm lint helm/quiz-app
```

Never commit `.tfvars`, credentials, kubeconfigs, private keys, database passwords, Azure access tokens or `.env` files.
