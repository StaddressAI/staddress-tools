# frozen_string_literal: true

module Staddress
  # Staddress AI API のデータモデル。
  #
  # OpenAPI 定義（openapi/staddress-api.yaml）に準拠する。
  # API は camelCase、Ruby 側は snake_case アクセサでアクセスできるようマッピングする。
  # 未知のフィールドは +raw+（元の Hash）から参照できる（前方互換）。
  module Models
    class Base
      # 元の（パース済み）レスポンス Hash。未定義フィールドはここから参照できる。
      attr_reader :raw

      class << self
        def fields
          @fields ||= {}
        end

        # フィールド定義。
        #   name  Ruby 側の snake_case 名（アクセサになる）
        #   key:  JSON 側のキー（省略時は name を camelCase 化）
        #   model: ネストしたモデルクラス
        #   list: true なら配列としてマッピング
        def field(name, key: nil, model: nil, list: false)
          fields[name] = { key: key || camelize(name), model: model, list: list }
          attr_reader name
        end

        # Hash からインスタンスを生成する。nil の場合は nil を返す。
        def from(data)
          return nil if data.nil?

          obj = allocate
          obj.send(:populate, data, fields)
          obj
        end

        def camelize(name)
          head, *rest = name.to_s.split("_")
          (rest.empty? ? head : head + rest.map(&:capitalize).join)
        end
      end

      private

      def populate(data, fields)
        @raw = data
        fields.each do |name, meta|
          value = data[meta[:key]]
          value = data[meta[:key].to_sym] if value.nil?
          instance_variable_set("@#{name}", cast(value, meta))
        end
      end

      def cast(value, meta)
        return nil if value.nil?
        return value unless meta[:model]
        return value.map { |item| meta[:model].from(item) } if meta[:list]

        meta[:model].from(value)
      end
    end

    # 住所の構成要素。
    class AddressComponents < Base
      field :pref
      field :pref_code
      field :city
      field :city_code
      field :oaza_cho
      field :chome_koaza
      field :chome_koaza_normalized
      field :chome_number
      field :street_number_block
      field :building_name
      field :room_number
      field :room_number_unit
      field :lon
      field :lat
      field :lg_code
      field :machiaza_id
    end

    # 解析の信頼度。
    class Confidence < Base
      field :score
      field :match_level
      field :query
    end

    # 住所解析結果。
    class ParseResult < Base
      field :normalized
      field :standard
      field :components, model: AddressComponents
      field :confidence, model: Confidence
    end

    # API エラー本体（エラーレスポンスの error フィールド）。
    class ErrorBody < Base
      field :code
      field :message
      field :request_id
      field :retry_after
    end

    # 一括解析の結果アイテム（result か error のいずれかを持つ）。
    class BatchItemResult < Base
      field :id
      field :result, model: ParseResult
      field :error, model: ErrorBody
    end

    class UsagePeriod < Base
      field :start
      field :end
    end

    class UsageCredit < Base
      field :valid_until
      field :total_amount
      field :used_amount
      field :remaining
    end

    class UsageDetail < Base
      field :period, model: UsagePeriod
      field :count
      field :monthly_limit
      field :contract_period_remaining
      field :credits, model: UsageCredit, list: true
    end

    # 利用状況レスポンス。
    class UsageResponse < Base
      field :account_name
      field :plan
      field :usage, model: UsageDetail
    end
  end
end
