# ~/.devops-env

Python project riêng cho bộ tooling DevOps dùng `uv`.

## First run

```bash
cd ~/.devops-env
uv sync
```

## Daily use

```bash
cd ~/.devops-env
uv lock
uv sync
uv run python
```

## Notes

- `.venv/` được tạo local khi chạy `uv sync`
- `uv.lock` là lockfile local của env này
- Python version được pin bằng `.python-version`
