module Hue
  class Sensor
    include TranslateKeys
    include EditableState

    # HUE_RANGE = 0..65535
    # SATURATION_RANGE = 0..255
    # BRIGHTNESS_RANGE = 0..255
    # COLOR_TEMPERATURE_RANGE = 153..500

    # Unique identification number.
    attr_reader :id

    # Bridge the light is associated with
    attr_reader :bridge

    # A unique, editable name given to the light.
    attr_accessor :name

    # Hue of the light. This is a wrapping value between 0 and 65535.
    # Both 0 and 65535 are red, 25500 is green and 46920 is blue.
    attr_reader :hue

    # A fixed name describing the type of light.
    attr_reader :type

    # The hardware model of the light.
    attr_reader :model

    # An identifier for the software version running on the light.
    attr_reader :software_version

    # Reserved for future functionality.
    attr_reader :point_symbol

    # attr_reader :state

    def initialize(client, bridge, id, hash)
      @client = client
      @bridge = bridge
      @id = id
      unpack(hash)
    end

    def name=(new_name)
      unless (1..32).include?(new_name.length)
        raise InvalidValueForParameter, 'name must be between 1 and 32 characters.'
      end

      body = {
        :name => new_name
      }

      uri = URI.parse(base_url)
      http = Net::HTTP.new(uri.host)
      response = http.request_put(uri.path, JSON.dump(body))
      response = JSON(response.body).first
      if response['success']
        @name = new_name
      # else
        # TODO: Error
      end
    end

    # # Indicates if a light can be reached by the bridge. Currently
    # # always returns true, functionality will be added in a future
    # # patch.
    # def reachable?
    #   @state['reachable']
    # end

    # @param transition The duration of the transition from the light’s current
    #   state to the new state. This is given as a multiple of 100ms and
    #   defaults to 4 (400ms). For example, setting transistiontime:10 will
    #   make the transition last 1 second.
    def set_state(attributes, transition = nil)
      body = translate_keys(attributes, STATE_KEYS_MAP)

      # Add transition
      body.merge!({:transitiontime => transition}) if transition

      uri = URI.parse("#{base_url}/state")
      http = Net::HTTP.new(uri.host)
      response = http.request_put(uri.path, JSON.dump(body))
      JSON(response.body)
    end

    # Refresh the state of the lamp
    def refresh
      json = JSON(Net::HTTP.get(URI.parse(base_url)))
      unpack(json)
    end
    
    def type
      case @type
      when 'ZLLPresence'
        :presence
      when 'ZLLTemperature'
        :temperature
      when 'ZLLLightLevel'
        :light_level
      else  
        @type
      end
    end
    
    def updated_at
      begin
        DateTime.parse(@state['lastupdated'])
      rescue
      end
    end
    
    def temperature
      self.refresh
      begin
        @state['temperature'].to_f / 100.0
      rescue
        nil
      end
    end
    
    def identifier
      @identifier
    end

    # def on?
    #   self.refresh
    #   @state['on']
    # end

  private

    KEYS_MAP = {
      :state => :state,
      :type => :type,
      :name => :name,
      :model => :modelid,
      :software_version => :swversion,
      :identifier => :uniqueid,
      :point_symbol => :pointsymbol
    }

    STATE_KEYS_MAP = {
      :temperature => :temperature
    }

    def unpack(hash)
      unpack_hash(hash, KEYS_MAP)
      unpack_hash(@state, STATE_KEYS_MAP)
      # @x, @y = @state['xy']
    end

    def base_url
      "http://#{@bridge.ip}/api/#{@client.username}/sensors/#{id}"
    end
  end
end
