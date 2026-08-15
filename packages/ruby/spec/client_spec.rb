# frozen_string_literal: true

RSpec.describe Staddress::Client do
  let(:key) { "sk_test" }
  let(:base) { "https://x.test" }

  PARSE_OK = {
    "result" => {
      "normalized" => "東京都港区六本木6丁目10-1",
      "standard" => "東京都港区六本木六丁目10-1",
      "components" => { "pref" => "東京都", "city" => "港区", "lat" => 35.6604, "lon" => 139.7292 },
      "confidence" => { "score" => 0.92, "matchLevel" => "residential_detail" }
    }
  }.freeze

  def client(**opts)
    described_class.new(api_key: key, base_url: base, **opts)
  end

  def stub_parse(status: 200, body: PARSE_OK)
    stub_request(:post, "#{base}/api/v1/addresses/parse")
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  # --- コンストラクタ --------------------------------------------------------

  describe "#initialize" do
    it "API キー未設定なら unauthorized を送出する" do
      expect { described_class.new }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("unauthorized")
        expect(err.http_status).to eq(0)
      end
    end

    it "環境変数 STADDRESS_API_KEY を利用する" do
      ENV["STADDRESS_API_KEY"] = "env_key"
      stub = stub_request(:get, "#{Staddress::DEFAULT_BASE_URL}/api/v1/usage")
             .with(headers: { "X-Api-Key" => "env_key" })
             .to_return(status: 200, body: "{}")
      described_class.new.get_usage
      expect(stub).to have_been_requested
    end

    it "base_url 末尾のスラッシュを除去する" do
      stub = stub_request(:post, "https://api.example.test/api/v1/addresses/parse")
             .to_return(status: 200, body: PARSE_OK.to_json)
      described_class.new(api_key: key, base_url: "https://api.example.test/").parse_address(input: "x")
      expect(stub).to have_been_requested
    end
  end

  # --- parse_address ---------------------------------------------------------

  describe "#parse_address" do
    it "解析結果を返し、正しいリクエストを送る" do
      stub_parse
      result = client.parse_address(input: "六本木ヒルズ", postal_code: "106-6100")

      expect(result.components.pref).to eq("東京都")
      expect(result.confidence.match_level).to eq("residential_detail")
      expect(
        a_request(:post, "#{base}/api/v1/addresses/parse")
          .with(
            headers: { "X-Api-Key" => key, "Content-Type" => "application/json" },
            body: { "input" => "六本木ヒルズ", "postalCode" => "106-6100" }
          )
      ).to have_been_made
    end

    it "postal_code 未指定なら body に含めない" do
      stub_parse
      client.parse_address(input: "a")
      expect(
        a_request(:post, "#{base}/api/v1/addresses/parse").with(body: { "input" => "a" })
      ).to have_been_made
    end

    it "input が空なら invalid_request を送出する" do
      expect { client.parse_address(input: "") }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("invalid_request")
      end
    end

    it "422 エラーを解釈する" do
      body = {
        "result" => nil,
        "error" => { "code" => "unresolved", "message" => "住所を特定できません。", "requestId" => "req-1" }
      }
      stub_parse(status: 422, body: body)

      expect { client.parse_address(input: "x") }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("unresolved")
        expect(err.http_status).to eq(422)
        expect(err.request_id).to eq("req-1")
      end
    end
  end

  # --- parse_batch -----------------------------------------------------------

  describe "#parse_batch" do
    it "一括解析結果を返す" do
      body = { "results" => [{ "id" => "1", "result" => PARSE_OK["result"] }] }
      stub_request(:post, "#{base}/api/v1/addresses/parse/batch")
        .to_return(status: 200, body: body.to_json)

      results = client.parse_batch([{ id: "1", address: "東京都" }])

      expect(results.size).to eq(1)
      expect(results.first.id).to eq("1")
      expect(results.first.result.components.pref).to eq("東京都")
      expect(
        a_request(:post, "#{base}/api/v1/addresses/parse/batch")
          .with(body: { "items" => [{ "id" => "1", "address" => "東京都" }] })
      ).to have_been_made
    end

    it "空配列なら invalid_request を送出する" do
      expect { client.parse_batch([]) }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("invalid_request")
      end
    end

    it "上限超過なら batch_size_exceeded を送出する" do
      items = Array.new(101) { |i| { id: i.to_s, address: "x" } }
      expect { client.parse_batch(items) }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("batch_size_exceeded")
      end
    end

    it "403 forbidden を解釈する" do
      body = { "error" => { "code" => "forbidden", "message" => "このプランでは利用できません。" } }
      stub_request(:post, "#{base}/api/v1/addresses/parse/batch")
        .to_return(status: 403, body: body.to_json)

      expect { client.parse_batch([{ id: "1", address: "x" }]) }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("forbidden")
        expect(err.http_status).to eq(403)
      end
    end
  end

  # --- get_usage -------------------------------------------------------------

  describe "#get_usage" do
    it "利用状況を返す" do
      body = { "accountName" => "Acme", "plan" => "free", "usage" => { "count" => 10, "monthlyLimit" => 100 } }
      stub_request(:get, "#{base}/api/v1/usage").to_return(status: 200, body: body.to_json)

      usage = client.get_usage
      expect(usage.plan).to eq("free")
      expect(usage.account_name).to eq("Acme")
      expect(usage.usage.monthly_limit).to eq(100)
    end

    it "401 unauthorized を解釈する" do
      body = { "error" => { "code" => "unauthorized", "message" => "API キーが無効です。" } }
      stub_request(:get, "#{base}/api/v1/usage").to_return(status: 401, body: body.to_json)

      expect { client.get_usage }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("unauthorized")
        expect(err.http_status).to eq(401)
      end
    end
  end

  # --- ネットワーク / タイムアウト ------------------------------------------

  describe "ネットワーク" do
    it "ネットワークエラーを network_error として送出する" do
      stub_request(:get, "#{base}/api/v1/usage").to_raise(SocketError.new("boom"))
      expect { client.get_usage }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("network_error")
      end
    end

    it "タイムアウトを timeout として送出する" do
      stub_request(:get, "#{base}/api/v1/usage").to_timeout
      expect { client.get_usage }.to raise_error(Staddress::Error) do |err|
        expect(err.code).to eq("timeout")
      end
    end
  end
end
