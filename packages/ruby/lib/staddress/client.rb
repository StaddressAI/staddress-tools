# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

require_relative "errors"
require_relative "models"

module Staddress
  DEFAULT_BASE_URL = "https://api.staddress.com"
  DEFAULT_TIMEOUT = 30
  MAX_BATCH_ITEMS = 100

  # Staddress AI API クライアント（同期）。
  #
  # 例:
  #   client = Staddress::Client.new(api_key: "sk_xxx")
  #   result = client.parse_address(input: "六本木ヒルズ 森タワー 52F")
  #   puts result.normalized
  class Client
    # @param api_key [String, nil] 省略時は環境変数 STADDRESS_API_KEY
    # @param base_url [String, nil] 省略時は STADDRESS_BASE_URL または既定値
    # @param timeout [Numeric] 接続・読み取りタイムアウト（秒）
    def initialize(api_key: nil, base_url: nil, timeout: DEFAULT_TIMEOUT)
      @api_key = api_key || ENV.fetch("STADDRESS_API_KEY", nil)
      if @api_key.nil? || @api_key.empty?
        raise Error.new(
          "API キーが設定されていません。api_key 引数または環境変数 STADDRESS_API_KEY を指定してください。",
          code: "unauthorized",
          http_status: 0
        )
      end

      base = base_url || ENV.fetch("STADDRESS_BASE_URL", nil) || DEFAULT_BASE_URL
      @base_url = base.sub(%r{/+\z}, "")
      @timeout = timeout
    end

    # 単件住所解析 (POST /api/v1/addresses/parse)。
    # @return [Staddress::Models::ParseResult]
    def parse_address(input:, postal_code: nil)
      if input.nil? || input.empty?
        raise Error.new("input は必須です。", code: "invalid_request", http_status: 0)
      end

      body = { "input" => input }
      body["postalCode"] = postal_code if postal_code && !postal_code.empty?

      data = request("POST", "/api/v1/addresses/parse", body)
      Models::ParseResult.from(data["result"]) || Models::ParseResult.from({})
    end

    # 一括住所解析 (POST /api/v1/addresses/parse/batch)。Standard プラン以上、最大 100 件。
    # @param items [Array<Hash>] 例: [{ id: "1", address: "東京都..." }]
    # @return [Array<Staddress::Models::BatchItemResult>]
    def parse_batch(items)
      list = items.to_a
      if list.empty?
        raise Error.new("items には1件以上を指定してください。", code: "invalid_request", http_status: 0)
      end
      if list.size > MAX_BATCH_ITEMS
        raise Error.new(
          "items は最大 #{MAX_BATCH_ITEMS} 件です（現在: #{list.size} 件）。",
          code: "batch_size_exceeded",
          http_status: 0
        )
      end

      data = request("POST", "/api/v1/addresses/parse/batch", { "items" => list })
      (data["results"] || []).map { |item| Models::BatchItemResult.from(item) }
    end

    # 利用状況取得 (GET /api/v1/usage)。
    # @return [Staddress::Models::UsageResponse]
    def get_usage
      data = request("GET", "/api/v1/usage", nil)
      Models::UsageResponse.from(data)
    end

    private

    def request(method, path, body)
      uri = URI.parse("#{@base_url}#{path}")
      req = build_request(method, uri, body)
      req["X-Api-Key"] = @api_key
      req["Content-Type"] = "application/json"

      response = perform(uri, req)
      interpret(response.code.to_i, response.body)
    end

    def build_request(method, uri, body)
      klass = { "GET" => Net::HTTP::Get, "POST" => Net::HTTP::Post }.fetch(method)
      req = klass.new(uri)
      req.body = JSON.generate(body) unless body.nil?
      req
    end

    def perform(uri, req)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http.request(req)
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Error.new("リクエストがタイムアウトしました。", code: "timeout", http_status: 0)
    rescue SocketError, SystemCallError, IOError
      raise Error.new("ネットワークエラーが発生しました。", code: "network_error", http_status: 0)
    end

    # HTTP レスポンスを解釈し、成功なら Hash を返す。エラーなら Error を送出する。
    def interpret(status, text)
      data = parse_json(text, status)

      if status >= 400
        err = data.is_a?(Hash) ? data["error"] : nil
        if err.is_a?(Hash) && err["code"] && err["message"]
          raise Error.from_body(err, status)
        end

        raise Error.new("API エラー (HTTP #{status})", code: "internal_error", http_status: status)
      end

      data.is_a?(Hash) ? data : {}
    end

    def parse_json(text, status)
      return nil if text.nil? || text.empty?

      JSON.parse(text)
    rescue JSON::ParserError
      raise Error.new("レスポンスの JSON 解析に失敗しました。", code: "internal_error", http_status: status)
    end
  end
end
