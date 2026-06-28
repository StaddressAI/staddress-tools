# staddress (Ruby Gem)

Staddress AI API 公式 Ruby SDK。

## ステータス

**Phase 4 — 未実装**

## インストール（予定）

```bash
gem install staddress
```

```ruby
# Gemfile
gem 'staddress'
```

## 使用例（予定）

```ruby
client = Staddress::Client.new(
  api_key: ENV['STADDRESS_API_KEY'],
  base_url: ENV['STADDRESS_BASE_URL']
)

result = client.parse_address(input: '六本木ヒルズ 森タワー 52F')
```

詳細: [docs/plan-tools.md §3.5](../../docs/plan-tools.md)
