# frozen_string_literal: true

module Staddress
  # Staddress API 呼び出しで発生したエラーを表す統一例外。
  #
  # - HTTP 4xx / 5xx で API がエラーボディを返した場合
  # - ネットワークエラー・タイムアウト（code: "network_error" / "timeout"）
  # - 入力バリデーションエラー（code: "invalid_request"）
  #
  # 属性:
  #   code         API エラーコード（"unauthorized", "quota_exceeded" 等）
  #   http_status  HTTP ステータスコード（ネットワークエラー時は 0）
  #   request_id   サポート問い合わせ用のリクエスト ID（あれば）
  #   retry_after  再試行可能日時（ISO 8601、あれば）
  class Error < StandardError
    attr_reader :code, :http_status, :request_id, :retry_after

    def initialize(message, code: "internal_error", http_status: 0, request_id: nil, retry_after: nil)
      super(message)
      @code = code
      @http_status = http_status
      @request_id = request_id
      @retry_after = retry_after
    end

    # API のエラーボディ（Hash）から Error を生成する。
    def self.from_body(body, http_status)
      new(
        body["message"] || "API error (#{body["code"]})",
        code: body["code"],
        http_status: http_status,
        request_id: body["requestId"],
        retry_after: body["retryAfter"]
      )
    end
  end
end
