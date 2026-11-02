# e2e 專用 nginx 規則

每次 e2e 測試需要的臨時 location 規則，請放在此目錄，檔名使用 `*.conf`。

- 由 `www.posdev.test.conf` 的 443 server 區塊以 `include /etc/nginx/conf.d/e2e/*.conf;` 載入。
- `*.conf` 已加入 .gitignore，不會進版控；本 README 與 `.gitkeep` 會保留。
- nginx 頂層 `include conf.d/*.conf` 不會遞迴，不會誤載此目錄。
- 新增或修改後需 reload nginx 才會生效。
