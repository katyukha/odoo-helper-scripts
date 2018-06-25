# Contributing to odoo-helper-scripts

Thank you for your interest in contributing to odoo-helper-scripts!

## Contributing to this project

1. Fork the repository on [GitHub](https://github.com/katyukha/odoo-helper-scripts) or [GitLab](https://gitlab.com/katyukha/odoo-helper-scripts/)
2. Create a new branch, e.g., `git checkout -b bug-12345` based on `dev` branch
3. Fix the bug or add the feature
4. Add or modify related help message (if necessary)
5. Add or modify documentation (if necessary) for your change
6. Add changelog entry for your change in *Unreleased* section
7. Commit and push it to your fork
8. Create Merge Request or Pull Request

## How to build documentation

Install [MkDocs](https://www.mkdocs.org/)

```bash
pip install mkdocs
```

Run `build_docs` script in repository root.

```bash
./scripts/build_docs.sh
```

Run MkDocs built-in dev server with following command in repository root.

```bash
mkdocs serve
```

Generated documentation will be available at `http://127.0.0.1:8000/`.
