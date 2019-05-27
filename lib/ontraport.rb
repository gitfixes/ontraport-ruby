require "httparty"

Dir[File.expand_path('../ontraport/*.rb', __FILE__)].each do |file|
  require file
end

# @author Hamza Tayeb
# @see https://api.ontraport.com/doc ONTRAPORT API Documentation
module Ontraport
  BASE_URL = 'https://api.ontraport.com/'
  API_VERSION = '1'

  # Describe a given object type, including the numeric object Id and the available fields.
  #
  # @example
  #   Ontraport.describe :contact
  #
  # @param object [Symbol] the type of object you want to describe
  # @raise [ArgumentError] if the argument is not a +Symbol+
  # @raise [ObjectNotFoundError] if the argument does not match any object defined in the schema
  # @return [Hash{String=>String,Hash}] object metadata. Keys are:
  #   - +'name'+ - name of the object
  #   - +'fields'+ - Hash containing the object's fields
  #   - +'schema_object_id'+ - numeric Id of the object, as a String
  def self.describe object
    unless object.class.eql? Symbol
      raise ArgumentError.new "Must provide a symbol for the object name."
    end

    unless metadata = objects_meta.data.find{ |k, v| v['name'].downcase.to_sym.eql? object }
      raise ObjectNotFoundError.new "No object matching #{object.inspect} could be found."
    end

    metadata.second.update 'schema_object_id' => metadata.first
  end

  # Clear the cache of object metadata generated by the describe call. Use this
  # if you make changes to custom fields or objects in your ONTRAPORT instance and
  # don't want to reload the Ontraport module.
  #
  # @example
  #   Ontraport.clear_describe_cache!
  #
  # @return [nil]
  def self.clear_describe_cache!
    @objects_meta_cache = nil
  end

  # @!group "Objects" Methods

  # Retrieve a single object of the specified type.
  #
  # @example
  #   Ontraport.get_object :contact, 12345
  #   #=> #<Ontraport::Response @data=...>
  #
  # @param object_type [Symbol] the type of object, for instance +:contact+
  # @param id [Integer] Id of the record you want
  # @return [Response]
  def self.get_object object_type, id
    objects_call :get, object_type, endpoint: '/object', data: { id: id }
  end

  # Retrieve a collection of objects of the specified type, matching the query
  # specified by the parameters.
  #
  # @example
  #   Ontraport.get_objects :contact, { condition: "email like '%@foo.com'", sort: 'lastname' }
  #
  # @see https://api.ontraport.com/doc/#!/objects/getObjects List of accepted params
  #
  # @param object_type [Symbol] the type of object
  # @param params [Hash] hash containing request parameters
  # @return [Response]
  def self.get_objects object_type, params={}
    objects_call :get, object_type, endpoint: '/objects', data: params
  end

  # Create an object with the given data
  #
  # @example
  #   Ontraport.create :contact, { email: 'foo@bar.com', firstname: 'Foo' }
  #   #=> #<Ontraport::Response @data=...>
  #
  # @see https://api.ontraport.com/doc/#!/objects/createObject API docs
  #
  # @param object_type [Symbol] the type of object
  # @param params [Hash] input data
  # @return [Response]
  def self.create object_type, params
    objects_call :post, object_type, endpoint: '/objects', data: params
  end

  # Create an object with the given data, or merge if the unique field matches another row.
  #
  # @example
  #   Ontraport.save_or_update :contact, { email: 'foo@bar.com', firstname: 'Foo' }
  #   #=> #<Ontraport::Response @data=...>
  #
  # @see https://api.ontraport.com/doc/#!/objects/createormergeObject API docs
  #
  # @param object_type [Symbol] the type of object
  # @param params [Hash] input data
  # @return [Response]
  def self.save_or_update object_type, params
    objects_call :post, object_type, endpoint: '/objects/saveorupdate', data: params
  end

  # Given an object type, Id, and a +Hash+ of changes, update an single row.
  #
  # @example
  #   Ontraport.update_object :contact, 12345, { firstname: 'ChangeMe' }
  #   #=> #<Ontraport::Response @data=...>
  #
  # @param object_type [Symbol] the type of object
  # @param params [Hash] update data. Use +.describe+ to get a list of available fields.
  # @return [Response]
  def self.update_object object_type, id, params
    objects_call :put, object_type, endpoint: '/objects', data: params.update(id: id)
  end

  # Add tags to objects matching the supplied conditions. In addition to various conditionals, you
  # may supply a list of Ids for objects you wish to tag (+ids+). The +add_list+ parameter (which contains the
  # Ids of the tags you want to add) is required.
  #
  # @note The +add_list+ and +ids+ parameters should be strings comprised of comma-delimeted Integers.
  #
  # @example
  #   Ontraport.tag_objects :contact, { add_list: '11111,22222', ids: '33333,44444' }
  #   #=> #<Ontraport::Response @data=...>
  #
  # @see https://api.ontraport.com/doc/#!/objects/addTag API docs
  #
  # @param object_type [Symbol] the type of object
  # @param params [Hash] parameters describing the conditions of the tag operation.
  # @return [Response]
  def self.tag_objects object_type, params
    objects_call :put, object_type, endpoint: '/objects/tag', data: params
  end

  # Remove tags from objects matching the supplied conditions. Interface is nearly identical to +#tag_objects+
  #
  # @note This method expects +remove_list+ as a required parameter.
  #
  # @see tag_objects
  # @see https://api.ontraport.com/doc/#!/objects/removeTag API docs
  #
  # @param object_type [Symbol] the type of object
  # @param params [Hash] parameters describing the conditions of the tag operation.
  # @return [Response]
  def self.untag_objects object_type, object:, tag:
    objects_call :delete, object_type, endpoint: '/objects/tag', data: params
  end

  # Add a subscription to an object.
  #
  # @example
  #   Ontraport.add_subscription :contact, 12345, [150,200], "Campaign", { range: 5 }
  #   #=> #<Ontraport::Response @data=...>
  #
  # @see https://api.ontraport.com/live/#!/objects/addSubscription API docs
  #
  # @param object_type [Symbol] the type of object
  # @param ids [Array, Integer] id or array of ids of objects to subscribe
  # @param add_list [Array, Integer] id or array of ids of Campaigns or Sequences to subscribe the object to
  # @param sub_type [String, nil] possible values are "Sequence" or "Campaign" defaults to "Campaign"
  # @param params [Hash, nil] extra stuff to add to request data. Use +.describe+ to get a list of available fields.
  # @return [Response]

  def self.add_subscription object_type, ids, add_list, sub_type = 'Campaign', params = {}
    objects_call :put, object_type, endpoint: '/objects/subscribe',
                                    data: params.update(
                                      ids: Array(ids).join(','),
                                      sub_type: sub_type,
                                      add_list: Array(add_list).join(',')
                                    )
  end

  def self.tag_by_name object_type, ids, add_names, params = {}
    objects_call :put, object_type, endpoint: '/objects/tagByName',
                                    data: params.update(
                                      ids: ids.split(','),
                                      add_names: add_names.split(',')
                                    )
  end
  
  # Remove a subscription from an object.
  #
  # @example
  #   Ontraport.remove_subscription :contact, 12345, [150,200], "Campaign", { range: 5 }
  #   #=> #<Ontraport::Response @data=...>
  #
  # @see https://api.ontraport.com/live/#!/objects/addSubscription API docs
  #
  # @param object_type [Symbol] the type of object
  # @param ids [Array, Integer] id or array of ids of objects to subscribe
  # @param remove_list [Array, Integer] id or array of ids of Campaigns or Sequences to unsubscribe the object to
  # @param sub_type [String, nil] possible values are "Sequence" or "Campaign" defaults to "Campaign"
  # @param params [Hash, nil] extra stuff to add to request data. Use +.describe+ to get a list of available fields.
  # @return [Response]

  def self.remove_subscription object_type, ids, remove_list, sub_type = 'Campaign', params = {}
    objects_call :delete, object_type, endpoint: '/objects/subscribe',
                                       data: params.update(
                                         ids: Array(ids).join(','),
                                         sub_type: sub_type,
                                         remove_list: Array(remove_list).join(',')
                                       )
  end

  # @!endgroup
  # @!group "Transactions" Methods

  # Get full information about an order
  #
  # @see https://api.ontraport.com/doc/#!/transactions/getOrder API docs
  #
  # @param order_id [Integer] Id of the order
  # @return [Response]
  def self.get_order order_id
    request_with_authentication :get, endpoint: '/transaction/order', data: { id: order_id }
  end

  # @!endgroup
  #

  private

  def self.request_with_authentication method, endpoint:, data: nil
    data_param = method.eql?(:get) ? :query : :body
    request_content = data_param.eql?(:body) ? data.to_json : data

    args = [method, "#{BASE_URL}#{API_VERSION}#{endpoint}"]
    kwargs = {
      :headers => { 'Api-Appid' => @configuration.api_id,
                    'Api-Key' => @configuration.api_key,
                    'Content-Type' => 'application/json' },
      data_param => request_content
    }

    response = HTTParty.send *args, **kwargs

    unless response.code.eql? 200
      error = "#{response.code} #{response.msg}"
      raise APIError.new(response.body.present? ? "#{error} - #{response.body}" : error)
    end

    parsed_response = response.parsed_response

    @configuration.debug_mode ? parsed_response.update(original_request: response.request) : nil

    Response.new **parsed_response.symbolize_keys
  end

  def self.objects_call method, object_type, endpoint:, data: {}
    metadata = describe object_type
    data.update 'objectID' => metadata['schema_object_id']

    request_with_authentication method, endpoint: endpoint, data: data
  end

  def self.objects_meta
    @objects_meta_cache ||= request_with_authentication :get, endpoint: '/objects/meta'
  end
end
