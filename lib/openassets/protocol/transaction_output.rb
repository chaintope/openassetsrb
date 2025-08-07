module OpenAssets
  module Protocol

    # Represents a transaction output and its asset ID and asset quantity.
    class TransactionOutput

      include OpenAssets::Util

      attr_accessor :value
      attr_accessor :script
      attr_accessor :asset_id
      attr_accessor :asset_quantity
      attr_accessor :output_type

      attr_accessor :account
      attr_accessor :metadata
      attr_accessor :asset_definition_url
      attr_accessor :asset_definition


      # @param [Integer] value The satoshi value of the output.
      # @param [Bitcoin::Script] script The script controlling redemption of the output.
      # @param [String] asset_id The asset ID of the output.
      # @param [Integer] asset_quantity The asset quantity of the output.
      # @param [OpenAssets::Transaction::OutPutType] output_type The type of the output.
      def initialize(value, script, asset_id = nil, asset_quantity = 0, output_type = OutputType::UNCOLORED, metadata = '')
        raise ArgumentError, "invalid output_type : #{output_type}" unless OutputType.all.include?(output_type)
        raise ArgumentError, "invalid asset_quantity. asset_quantity should be unsignd integer. " unless asset_quantity.between?(0, MarkerOutput::MAX_ASSET_QUANTITY)
        @value = value
        @script = script
        @asset_id = asset_id
        @asset_quantity = asset_quantity
        @output_type = output_type
        @metadata = metadata
        load_asset_definition_url
      end

      # calculate asset amount.
      # asset amount is the value obtained by converting the asset quantity to the unit of divisibility that are defined in the Asset definition file.
      def asset_amount
        d = divisibility
        d > 0 ? (@asset_quantity.to_f / (10 ** d)).to_f : @asset_quantity
      end

      # get divisibility defined by asset definition file.
      def divisibility
        return 0 if !valid_asset_definition? || @asset_definition.divisibility.nil?
        @asset_definition.divisibility
      end

      # Verify proof of authenticity.
      def proof_of_authenticity
        valid_asset_definition? ? @asset_definition.proof_of_authenticity : false
      end

      # convert to hash object.
      def to_hash
        {
            'address' =>  address,
            'oa_address' => oa_address,
            'script' => @script.to_payload.bth,
            'script_type' => script_type,
            'amount' => satoshi_to_coin(@value),
            'asset_id' => @asset_id,
            'asset_quantity' => @asset_quantity.to_s,
            'asset_amount' => asset_amount.to_s,
            'account' => @account,
            'asset_definition_url' => @asset_definition_url,
            'proof_of_authenticity' => proof_of_authenticity,
            'output_type' => OpenAssets::Protocol::OutputType.output_type_label(@output_type)
        }
      end

      def address
        return @script.to_addr if @script.p2pkh? || @script.p2sh? || @script.p2wpkh? || @script.p2wsh?
        nil # TODO Bitcoin::Script#to_addr after it enable
      end

      def oa_address
        a = address
        return nil if a.nil?
        address_to_oa_address(a)
      end

      # get pubkey script type
      def script_type
        return 'pubkeyhash' if script.p2pkh?
        return 'scripthash' if script.p2sh?
        return 'nulldata' if script.standard_op_return?
        return 'multisig' if script.multisig?
        return 'witness_v0_keyhash' if script.p2wpkh?
        return 'witness_v0_scripthash' if script.p2wsh?
        'nonstandard'
      end

      private

      @@definition_cache = {}

      # get Asset definition url that is included metadata.
      def load_asset_definition_url
        @asset_definition_url = ''
        return if @metadata.nil? || @metadata.length == 0
        if @metadata.start_with?('u=')
          @asset_definition = load_asset_definition(metadata_url)
          if valid_asset_definition?
            @asset_definition_url = metadata_url
          else
            @asset_definition_url = "The asset definition is invalid. #{metadata_url}"
          end
        else
          @asset_definition_url = 'Invalid metadata format.'
        end
      end

      def metadata_url
        unless @metadata.nil?
           @metadata.slice(2..-1)
        end
      end

      def valid_asset_definition?
        !@asset_definition.nil? && @asset_definition.include_asset_id?(@asset_id)
      end

      def load_asset_definition(url)
        unless @@definition_cache.has_key?(url)
          loader = AssetDefinitionLoader.new(metadata_url)
          @@definition_cache[url] = loader.load_definition
        end
        @@definition_cache[url]
      end
    end

  end
end