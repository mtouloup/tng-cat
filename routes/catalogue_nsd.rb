##
## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).

# @see SonCatalogue
# class SonataCatalogue < Sinatra::Application
class CatalogueV1 < SonataCatalogue
  # require 'addressable/uri'

  ### NSD API METHODS ###

  # @method get_nssSS
  # @overload get '/catalogues/network-services/?'
  #	Returns a list of NSs
  # -> List many descriptors
  get '/network-services/?' do
    params['page_number'] ||= DEFAULT_PAGE_NUMBER
    params['page_size'] ||= DEFAULT_PAGE_SIZE

    #uri = Addressable::URI.new
    #uri.query_values = params
    # puts 'params', params
    # puts 'query_values', uri.query_values
    #logger.info "Catalogue: entered GET /network-services?#{uri.query}"
    logger.info "Catalogue: entered GET /network-services?#{query_string}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    #puts 'keyed_params', keyed_params

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Get rid of :page_number and :page_size
    [:page_number, :page_size].each { |k| keyed_params.delete(k) }
    # puts 'keyed_params(1)', keyed_params

    # Check for special case (:version param == last)
    if keyed_params.key?(:version) && keyed_params[:version] == 'last'
      # Do query for last version -> get_nsd_ns_vendor_last_version

      keyed_params.delete(:version)
      # puts 'keyed_params(2)', keyed_params

      nss = Ns.where((keyed_params)).sort({ 'version' => -1 }) #.limit(1).first()
      logger.info "Catalogue: NSDs=#{nss}"
      # nss = nss.sort({"version" => -1})
      # puts 'nss: ', nss.to_json

      if nss && nss.size.to_i > 0
        logger.info "Catalogue: leaving GET /network-services?#{query_string} with #{nss}"

        # Paginate results
        # nss = nss.paginate(:page_number => params[:page_number],
        # :page_size => params[:page_size]).sort({"version" => -1})

        nss_list = []
        checked_list = []

        nss_name_vendor = Pair.new(nss.first.name, nss.first.vendor)
        # p 'nss_name_vendor:', [nss_name_vendor.one, nss_name_vendor.two]
        checked_list.push(nss_name_vendor)
        nss_list.push(nss.first)

        nss.each do |nsd|
          # p 'Comparison: ', [nsd.name, nsd.vendor].to_s + [nss_name_vendor.one, nss_name_vendor.two].to_s
          if (nsd.name != nss_name_vendor.one) || (nsd.vendor != nss_name_vendor.two)
            nss_name_vendor = Pair.new(nsd.name, nsd.vendor)
            # p 'nss_name_vendor(x):', [nss_name_vendor.one, nss_name_vendor.two]
            # checked_list.each do |pair|
            #  p [pair.one, nss_name_vendor.one], [pair.two, nss_name_vendor.two]
            #  p pair.one == nss_name_vendor.one && pair.two == nss_name_vendor.two
          end
          nss_list.push(nsd) unless checked_list.any? { |pair| pair.one == nss_name_vendor.one &&
              pair.two == nss_name_vendor.two }
          checked_list.push(nss_name_vendor)
        end
        # puts 'nss_list:', nss_list.each {|ns| p ns.name, ns.vendor}
      else
        # logger.error "ERROR: 'No NSDs were found'"
        logger.info "Catalogue: leaving GET /network-services?#{query_string} with 'No NSDs were found'"
        # json_error 404, "No NSDs were found"
        nss_list = []
      end
      # nss = nss_list.paginate(:page => params[:page_number], :per_page =>params[:page_size])
      nss = apply_limit_and_offset(nss_list, page_number=params[:page_number],
                                   page_size=params[:page_size])

    else
      # Do the query
      nss = Ns.where(keyed_params)
      logger.info "Catalogue: NSDs=#{nss}"
      # puts nss.to_json
      if nss && nss.size.to_i > 0
        #logger.info "Catalogue: leaving GET /network-services?#{uri.query} with #{nss}"
        logger.info "Catalogue: leaving GET /network-services?#{query_string} with #{nss}"

        # Paginate results
        nss = nss.paginate(page_number: params[:page_number], page_size: params[:page_size])

      else
        #logger.info "Catalogue: leaving GET /network-services?#{uri.query} with 'No NSDs were found'"
        logger.info "Catalogue: leaving GET /network-services?#{query_string} with 'No NSDs were found'"
        # json_error 404, "No NSDs were found"
      end
    end

    response = ''
    case request.content_type
      when 'application/json'
        response = nss.to_json
      when 'application/x-yaml'
        response = json_to_yaml(nss.to_json)
      else
        halt 415
    end
    halt 200, response
  end

  # @method get_ns_sp_ns_id
  # @overload get '/catalogues/network-services/:id/?'
  #	  GET one specific descriptor
  #	  @param :id [Symbol] unique identifier
  # Show a NS by internal ID (uuid)
  get '/network-services/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: GET /network-services/#{params[:id]}"

      begin
        ns = Ns.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The NSD ID #{params[:id]} does not exist" unless ns
      end
      logger.debug "Catalogue: leaving GET /network-services/#{params[:id]}\" with NSD #{ns}"

      response = ''
      case request.content_type
        when 'application/json'
          response = ns.to_json
        when 'application/x-yaml'
          response = json_to_yaml(ns.to_json)
        else
          halt 415
      end
      halt 200, response

    end
    logger.debug "Catalogue: leaving GET /network-services/#{params[:id]} with 'No NSD ID specified'"
    json_error 400, 'No NSD ID specified'
  end

  # @method post_nss
  # @overload post '/catalogues/network-services'
  # Post a NS in JSON or YAML format
  post '/network-services' do


    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a NSD, the json object sent to API must contain just data inside
        # of the nsd, without the json field nsd: before
        ns, errors = parse_yaml(request.body.read)
        halt 400, errors.to_json if errors

        # Translate from YAML format to JSON format
        new_ns_json = yaml_to_json(ns)

        # Validate JSON format
        new_ns, errors = parse_json(new_ns_json)
        # puts 'ns: ', new_ns.to_json
        # puts 'new_ns id', new_ns['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_ns, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

    # Validate NS
    json_error 400, 'ERROR: NS Vendor not found' unless new_ns.key?('vendor')
    json_error 400, 'ERROR: NS Name not found' unless new_ns.key?('name')
    json_error 400, 'ERROR: NS Version not found' unless new_ns.key?('version')

    # --> Validation disabled
    # Validate NSD
    # begin
    #   postcurb settings.nsd_validator + '/nsds', ns.to_json, :content_type => :json
    # rescue => e
    #   halt 500, {'Content-Type' => 'text/plain'}, "Validator mS unreachable."
    # end

    # Check if NS already exists in the catalogue by name, vendor and version
    begin
      ns = Ns.find_by({ 'name' => new_ns['name'], 'vendor' => new_ns['vendor'], 'version' => new_ns['version'] })
      json_return 200, 'Duplicated NS Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end
    # Check if NSD has an ID (it should not) and if it already exists in the catalogue
    begin
      ns = Ns.find_by({ '_id' => new_ns['_id'] })
      json_return 200, 'Duplicated NS ID'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Save to DB
    begin
      new_nsd = {}
      # Generate the UUID for the descriptor
      # new_nsd['nsd'] = new_ns
      new_nsd = new_ns
      new_nsd['_id'] = SecureRandom.uuid
      new_nsd['status'] = 'active'
      new_nsd['signature'] = 'null'
      ns = Ns.create!(new_nsd)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated NS ID' if e.message.include? 'E11000'
    end

    puts 'New NS has been added'
    response = ''
    case request.content_type
      when 'application/json'
        response = ns.to_json
      when 'application/x-yaml'
        response = json_to_yaml(ns.to_json)
      else
        halt 415
    end
    halt 201, response
  end

  # @method update_nss
  # @overload put '/catalogues/network-services/?'
  # Update a NS by vendor, name and version in JSON or YAML format
  ## Catalogue - UPDATE
  put '/network-services/?' do
    # uri = Addressable::URI.new
    # uri.query_values = params
    # puts 'params', params
    # puts 'query_values', uri.query_values
    logger.info "Catalogue: entered PUT /network-services?#{query_string}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    # puts 'keyed_params', keyed_params

    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Return 400 if params are empty
    json_error 400, 'Update parameters are null' if keyed_params.empty?

    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a NSD, the json object sent to API must contain just data inside
        # of the nsd, without the json field nsd: before
        ns, errors = parse_yaml(request.body.read)
        halt 400, errors.to_json if errors

        # Translate from YAML format to JSON format
        new_ns_json = yaml_to_json(ns)

        # Validate JSON format
        new_ns, errors = parse_json(new_ns_json)
        # puts 'ns: ', new_ns.to_json
        # puts 'new_ns id', new_ns['_id'].to_json
        halt 400, errors.to_json if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_ns, errors = parse_json(request.body.read)
        halt 400, errors.to_json if errors
    end

    # Validate NS
    # Check if same vendor, Name, Version do already exists in the database
    json_error 400, 'ERROR: NS Vendor not found' unless new_ns.key?('vendor')
    json_error 400, 'ERROR: NS Name not found' unless new_ns.key?('name')
    json_error 400, 'ERROR: NS Version not found' unless new_ns.key?('version')

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Retrieve stored version
    if keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      json_error 400, 'Update Vendor, Name and Version parameters are null'
    else
      begin
        ns = Ns.find_by({ 'vendor' => keyed_params[:vendor], 'name' => keyed_params[:name],
                          'version' => keyed_params[:version] })
        puts 'NS is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
    end
    # Check if NS already exists in the catalogue by name, group and version
    begin
      ns = Ns.find_by({ 'name' => new_ns['name'], 'vendor' => new_ns['vendor'], 'version' => new_ns['version'] })
      json_return 200, 'Duplicated NS Name, Vendor and Version'
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Update to new version
    puts 'Updating...'
    new_ns['_id'] = SecureRandom.uuid # Unique UUIDs per NSD entries
    nsd = new_ns

    # --> Validation disabled
    # Validate NSD
    # begin
    #	  postcurb settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
    # rescue => e
    #	  logger.error e.response
    #	return e.response.code, e.response.body
    # end

    begin
      new_ns = Ns.create!(nsd)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated NS ID' if e.message.include? 'E11000'
    end
    logger.debug "Catalogue: leaving PUT /network-services?#{query_string}\" with NSD #{new_ns}"

    begin
      new_ns = Ns.create!(new_nsd)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated NS ID' if e.message.include? 'E11000'
    end
    logger.debug "Catalogue: leaving PUT /network-services?#{query_string}\" with NSD #{new_ns}"

    response = ''
    case request.content_type
      when 'application/json'
        response = new_ns.to_json
      when 'application/x-yaml'
        response = json_to_yaml(new_ns.to_json)
      else
        halt 415
    end
    halt 200, response
  end

  # @method update_nss_id
  # @overload put '/catalogues/network-services/:id/?'
  # Update a NS in JSON or YAML format
  ## Catalogue - UPDATE
  put '/network-services/:id/?' do
    # Return if content-type is invalid
    halt 415 unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    unless params[:id].nil?
      logger.debug "Catalogue: PUT /network-services/#{params[:id]}"

      # Transform 'string' params Hash into keys
      keyed_params = keyed_hash(params)
      # puts 'keyed_params', keyed_params

      # Check for special case (:status param == <new_status>)
      p 'Special case detected= new_status'
      if keyed_params.key?(:status)
        p 'Detected key :status'
        # Do update of Descriptor status -> update_ns_status
        # uri = Addressable::URI.new
        # uri.query_values = params
        logger.info "Catalogue: entered PUT /network-services/#{query_string}"

        # Validate NS
        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          ns = Ns.find_by({ '_id' => params[:id] })
          puts 'NS is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, 'This NSD does not exists'
        end

        # Validate new status
        p 'Validating new status(keyed_params): ', keyed_params[:status]
        # p "Validating new status(params): ", params[:new_status]
        valid_status = %w(active inactive delete)
        if valid_status.include? keyed_params[:status]
          # Update to new status
          begin
            # ns.update_attributes(:status => params[:new_status])
            ns.update_attributes(status: keyed_params[:status])
          rescue Moped::Errors::OperationFailure => e
            json_error 400, 'ERROR: Operation failed'
          end
        else
          json_error 400, "Invalid new status #{keyed_params[:status]}"
        end

        # --> Validation disabled
        # Validate NSD
        # begin
        #	  postcurb settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
        # rescue => e
        #	  logger.error e.response
        #	  return e.response.code, e.response.body
        # end

        halt 200, "Status updated to {#{query_string}}"

      else
        # Compatibility support for YAML content-type
        case request.content_type
          when 'application/x-yaml'
            # Validate YAML format
            # When updating a NSD, the json object sent to API must contain just data inside
            # of the nsd, without the json field nsd: before
            ns, errors = parse_yaml(request.body.read)
            halt 400, errors.to_json if errors

            # Translate from YAML format to JSON format
            new_ns_json = yaml_to_json(ns)

            # Validate JSON format
            new_ns, errors = parse_json(new_ns_json)
            # puts 'ns: ', new_ns.to_json
            # puts 'new_ns id', new_ns['_id'].to_json
            halt 400, errors.to_json if errors

          else
            # Compatibility support for JSON content-type
            # Parses and validates JSON format
            new_ns, errors = parse_json(request.body.read)
            halt 400, errors.to_json if errors
        end

        # Validate NS
        # Check if same vendor, Name, Version do already exists in the database
        json_error 400, 'ERROR: NS Vendor not found' unless new_ns.key?('vendor')
        json_error 400, 'ERROR: NS Name not found' unless new_ns.key?('name')
        json_error 400, 'ERROR: NS Version not found' unless new_ns.key?('version')

        # Retrieve stored version
        begin
          puts 'Searching ' + params[:id].to_s
          ns = Ns.find_by({ '_id' => params[:id] })
          puts 'NS is found'
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "The NSD ID #{params[:id]} does not exist"
        end

        # Check if NS already exists in the catalogue by name, vendor and version
        begin
          ns = Ns.find_by({ 'name' => new_ns['name'], 'vendor' => new_ns['vendor'], 'version' => new_ns['version'] })
          json_return 200, 'Duplicated NS Name, Vendor and Version'
        rescue Mongoid::Errors::DocumentNotFound => e
          # Continue
        end

        # Update to new version
        puts 'Updating...'
        new_ns['_id'] = SecureRandom.uuid
        nsd = new_ns

        # --> Validation disabled
        # Validate NSD
        # begin
        #	  postcurb settings.nsd_validator + '/nsds', nsd.to_json, :content_type => :json
        # rescue => e
        #	  logger.error e.response
        #	  return e.response.code, e.response.body
        # end

        begin
          new_ns = Ns.create!(nsd)
        rescue Moped::Errors::OperationFailure => e
          json_return 200, 'Duplicated NS ID' if e.message.include? 'E11000'
        end
        logger.debug "Catalogue: leaving PUT /network-services/#{params[:id]}\" with NSD #{new_ns}"

        response = ''
        case request.content_type
          when 'application/json'
            response = new_ns.to_json
          when 'application/x-yaml'
            response = json_to_yaml(new_ns.to_json)
          else
            halt 415
        end
        halt 200, response
      end
    end
    logger.debug "Catalogue: leaving PUT /network-services/#{params[:id]} with 'No NSD ID specified'"
    json_error 400, 'No NSD ID specified'
  end

  # @method delete_nsd_sp_ns
  # @overload delete '/network-services/?'
  #	Delete a NS by vendor, name and version
  delete '/network-services/?' do
    # uri = Addressable::URI.new
    # uri.query_values = params
    # puts 'params', params
    # puts 'query_values', uri.query_values
    logger.info "Catalogue: entered DELETE /network-services?#{query_string}"

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)
    # puts 'keyed_params', keyed_params

    unless keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      begin
        ns = Ns.find_by({ 'vendor' => keyed_params[:vendor], 'name' => keyed_params[:name],
                          'version' => keyed_params[:version]} )
        puts 'NS is found'
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist"
      end
      logger.debug "Catalogue: leaving DELETE /network-services?#{query_string}\" with NSD #{ns}"
      ns.destroy
      halt 200, 'OK: NSD removed'
    end
    logger.debug "Catalogue: leaving DELETE /network-services?#{query_string} with 'No NSD Vendor, Name, Version specified'"
    json_error 400, 'No NSD Vendor, Name, Version specified'
  end

  # @method delete_nsd_sp_ns_id
  # @overload delete '/catalogues/network-service/:id/?'
  #	  Delete a NS by its ID
  #	  @param :id [Symbol] unique identifier
  # Delete a NS by uuid
  delete '/network-services/:id/?' do
    unless params[:id].nil?
      logger.debug "Catalogue: DELETE /network-services/#{params[:id]}"
      begin
        ns = Ns.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        logger.error e
        json_error 404, "The NSD ID #{params[:id]} does not exist" unless ns
      end
      logger.debug "Catalogue: leaving DELETE /network-services/#{params[:id]}\" with NSD #{ns}"
      ns.destroy
      halt 200, 'OK: NSD removed'
    end
    logger.debug "Catalogue: leaving DELETE /network-services/#{params[:id]} with 'No NSD ID specified'"
    json_error 400, 'No NSD ID specified'
  end
end

class CatalogueV2 < SonataCatalogue
  ### NSD API METHODS ###

  # @method get_nssSS
  # @overload get '/catalogues/network-services/?'
  #	Returns a list of NSs
  # -> List many descriptors
  get '/network-services/?' do

    # Logger details
    operation = "GET /v2/network-services?#{query_string}"
    component = __method__.to_s
    time_req_begin = Time.now.utc
    logger.cust_info(start_stop:'START', component: component, operation: operation, message: "Started at #{time_req_begin}")

    # Return if content-type is invalid
    json_error 415, 'Support of x-yaml and json', component, operation, time_req_begin unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    params['page_number'] ||= DEFAULT_PAGE_NUMBER
    params['page_size'] ||= DEFAULT_PAGE_SIZE

    #Delete key "captures" if present
    params.delete(:captures) if params.key?(:captures)


    # Split keys in meta_data and data
    # Then transform 'string' params Hash into keys
    keyed_params = add_descriptor_level('nsd', params)

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Get rid of :page_number and :page_size
    [:page_number, :page_size].each { |k| keyed_params.delete(k) }
    nss = []
    # Check for special case (:version param == last)
    if keyed_params.key?(:'nsd.version') && keyed_params[:'nsd.version'] == 'last'
      # Do query for last version -> get_nsd_ns_vendor_last_version
      keyed_params.delete(:'nsd.version')

      nss = Nsd.where((keyed_params)).sort({ 'nsd.version' => -1 }) #.limit(1).first()
      # nss = nss.sort({"version" => -1})

      if nss && nss.size.to_i > 0
        logger.cust_debug(component: component, operation: operation, message: "NSDs=#{nss}")

        nss_list = []
        checked_list = []

        # nss_name_vendor = Pair.new(nss.first.name, nss.first.vendor)
        nss_name_vendor = Pair.new(nss.first.nsd['name'], nss.first.nsd['vendor'])
        checked_list.push(nss_name_vendor)
        nss_list.push(nss.first)

        nss.each do |nsd|
          # if (nsd.name != nss_name_vendor.one) || (nsd.vendor != nss_name_vendor.two)
          if (nsd.nsd['name'] != nss_name_vendor.one) || (nsd.nsd['vendor'] != nss_name_vendor.two)
            # nss_name_vendor = Pair.new(nsd.name, nsd.vendor)
            nss_name_vendor = Pair.new(nsd.nsd['name'], nsd.nsd['vendor'])
            # checked_list.each do |pair|
          end
          nss_list.push(nsd) unless checked_list.any? { |pair| pair.one == nss_name_vendor.one &&
              pair.two == nss_name_vendor.two }
          checked_list.push(nss_name_vendor)
        end
      else
        logger.cust_debug(component: component, operation: operation, message: "No NSDs were found")
        nss_list = []
      end
      nss = apply_limit_and_offset(nss_list, page_number=params[:page_number],
                                   page_size=params[:page_size])
    elsif keyed_params.key?(:'nsd.count')
      [:'nsd.count'].each { |k| keyed_params.delete(k) }
      nss = Nsd.where(keyed_params).count()
      number = {}
      number['count'] = nss.to_s
      nss = number
    else
      # Do the query
      keyed_params = parse_keys_dict(:nsd, keyed_params)
      nss = Nsd.where(keyed_params)

      # Set total count for results
      headers 'Record-Count' => nss.count.to_s
      if nss && nss.size.to_i > 0
        logger.cust_debug(component: component, operation: operation, message: "NSDs=#{nss}")
        # Paginate results
        nss = nss.paginate(page_number: params[:page_number], page_size: params[:page_size])
      else
        logger.cust_debug(component: component, operation: operation, message: "No NSDs were found")
      end
    end

    # Format descriptors in unified format (either 5gtango, osm and onap)
    arr = []
    JSON.parse(nss.to_json).each do |desc|
      if number
        arr = nss
      else
        arr << transform_descriptor(desc, type_of_desc='nsd', platform = desc['platform'])
      end

    end
    logger.cust_info(status: 200, start_stop: 'STOP', message: "Ended at #{Time.now.utc}", component: component, operation: operation, time_elapsed: "#{Time.now.utc - time_req_begin }")

    response = case request.content_type
      when 'application/json'
        arr.any? ? arr.to_json : nss.to_json
      else
        arr.any? ? json_to_yaml(arr.to_json) : json_to_yaml(nss.to_json)
               end

    halt 200, {'Content-type' => request.content_type}, response
  end

  # @method get_ns_sp_ns_id
  # @overload get '/catalogues/network-services/:id/?'
  #	  GET one specific descriptor
  #	  @param :id [Symbol] unique identifier
  # Show a NS by internal ID (uuid)
  get '/network-services/:id/?' do

    # Logger details
    operation = "GET /v2/network-services/#{params[:id]}"
    component = __method__.to_s
    time_req_begin = Time.now.utc

    logger.cust_info(start_stop:'START', component: component, operation: operation, message: "Started at #{time_req_begin}")

    # Return if content-type is invalid
    json_error 415, 'Support of x-yaml and json', component, operation, time_req_begin unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    unless params[:id].nil?

      begin
        ns = Nsd.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD ID #{params[:id]} does not exist", component, operation, time_req_begin unless ns
      end
      logger.cust_debug(component: component, operation: operation, message: "NSDs=#{ns}")
      logger.cust_info(status: 200, start_stop: 'STOP', message: "Ended at #{Time.now.utc}", component: component, operation: operation, time_elapsed: "#{Time.now.utc - time_req_begin }")

      # Transform descriptor in its initial form
      ns = transform_descriptor(ns, type_of_desc='nsd', platform=ns['platform'])

      response = case request.content_type
        when 'application/json'
          ns.to_json
        else
          json_to_yaml(ns.to_json)
                 end
      halt 200, {'Content-type' => request.content_type}, response

    end
    logger.cust_debug(component: component, operation: operation, message: "No NSD ID specified")
    json_error 400, 'No NSD ID specified', component, operation, time_req_begin
  end

  # @method post_nss
  # @overload post '/catalogues/network-services'
  # Post a NS in JSON or YAML format
  post '/network-services' do

    # Logger details
    operation = "POST /v2/network-services"
    component = __method__.to_s
    time_req_begin = Time.now.utc

    logger.cust_info(start_stop:'START', component: component, operation: operation, message: "Started at #{time_req_begin}")

    # Return if content-type is invalid
    json_error 415, 'Support of x-yaml and json', component, operation, time_req_begin unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # # Fetch body request and check if blank
    # json_error 400, "Empty body request", component, operation, time_req_begin if request.body.read.blank?


    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a NSD, the json object sent to API must contain just data inside
        # of the nsd, without the json field nsd: before
        ns, errors = parse_yaml(request.body.read)
        json_error 400, errors, component, operation, time_req_begin if errors

        # Translate from YAML format to JSON format
        new_ns_json = yaml_to_json(ns)

        # Validate JSON format
        new_ns, errors = parse_json(new_ns_json)
        json_error 400, errors, component, operation, time_req_begin if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_ns, errors = parse_json(request.body.read)
        json_error 400, errors, component, operation, time_req_begin if errors
    end

    #Delete key "captures" if present
    params.delete(:captures) if params.key?(:captures)

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)


    # Retrieve platform and place as metadata
    #
    platform = if keyed_params.key?(:platform)
      keyed_params[:platform].downcase
        else
          '5gtango'
        end

    bool_cond = (platform.eql?('osm') | platform.eql?('onap')) & new_ns.key?('name')
    json_error 400, 'Platform not aligned with format of descriptor', component, operation, time_req_begin if bool_cond


    new_ns, heads = extract_osm_onap(new_ns, platform)

    # Validate NS
    json_error 400, 'NS Vendor not found', component, operation, time_req_begin unless new_ns.key?('vendor')
    json_error 400, 'NS Name not found', component, operation, time_req_begin unless new_ns.key?('name')
    json_error 400, 'NS Version not found', component, operation, time_req_begin unless new_ns.key?('version')


    # Check if NS already exists in the catalogue by name, vendor and version
    begin
      ns = Nsd.find_by({ 'nsd.name' => new_ns['name'], 'nsd.vendor' => new_ns['vendor'],
                         'nsd.version' => new_ns['version'], 'platform' => platform  })
      ns.update_attributes(pkg_ref: ns['pkg_ref'] + 1)
      logger.cust_debug(component: component, operation: operation, message: "Pkg_ref updated to #{ns['pkg_ref']}")
      logger.cust_info(status: 200, start_stop: 'STOP', message: "Ended at #{Time.now.utc}", component: component, operation: operation, time_elapsed: "#{Time.now.utc - time_req_begin }")

      # Transform descriptor in its initial form
      ns = transform_descriptor(ns, type_of_desc = 'nsd', platform=platform)

      response = case request.content_type
        when 'application/json'
          ns.to_json
        else
          json_to_yaml(ns.to_json)
                 end
      halt 200, {'Content-type' => request.content_type}, response
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    # Check if NSD has an ID (it should not) and if it already exists in the catalogue
    begin
      ns = Nsd.find_by({ '_id' => new_ns['_id'] })
      json_error 409, 'Duplicated NS ID', component, operation, time_req_begin
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    username = if keyed_params.key?(:username)
      keyed_params[:username]
    else
      nil
               end

    # Save to DB
    new_nsd = {}
    new_nsd['nsd'] = new_ns
    # Generate the UUID for the descriptor
    new_nsd['_id'] = SecureRandom.uuid
    new_nsd['platform'] = platform
    new_nsd['header'] = heads if platform.eql?('osm') | platform.eql?('onap')
    new_nsd['status'] = 'active'
    new_nsd['pkg_ref'] = 1
    # Signature will be supported
    new_nsd['signature'] = nil
    new_nsd['md5'] = checksum new_ns.to_s
    new_nsd['username'] = username

    # First, Refresh dictionary about the new entry
    update_entr_dict(new_nsd, :nsd)

    # Then, create descriptor
    begin
      ns = Nsd.create!(new_nsd)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated NS ID', component, operation, time_req_begin if e.message.include? 'E11000'
    end
    logger.cust_debug(component: component, operation: operation, message: "New NS has been added")
    logger.cust_info(status: 201, start_stop: 'STOP', message: "Ended at #{Time.now.utc}", component: component, operation: operation, time_elapsed: "#{Time.now.utc - time_req_begin }")

    # Transform descriptor to its initial form
    ns = transform_descriptor(ns, type_of_desc='nsd', platform=platform)

    response = case request.content_type
      when 'application/json'
        ns.to_json
      else
        json_to_yaml(ns.to_json)
               end
    halt 201, {'Content-type' => request.content_type}, response
  end

  # @method update_nss
  # @overload put '/catalogues/network-services/?'
  # Update a NS by vendor, name and version in JSON or YAML format
  ## Catalogue - UPDATE
  put '/network-services/?' do

    # Logger details
    operation = "PUT /v2/network-services?#{query_string}"
    component = __method__.to_s
    time_req_begin = Time.now.utc

    logger.cust_info(start_stop:'START', component: component, operation: operation, message: "Started at #{time_req_begin}")

    # Return if content-type is invalid
    json_error 415, 'Support of x-yaml and json', component, operation, time_req_begin unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    # Return 400 if params are empty
    json_error 400, 'Update parameters are null', component, operation, time_req_begin if keyed_params.empty?

    #Delete key "captures" if present
    params.delete(:captures) if params.key?(:captures)
    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)

    # # Retrieve body request
    # json_error 400, "Empty body request", component, operation, time_req_begin if request.body.read.blank?


    # Compatibility support for YAML content-type
    case request.content_type
      when 'application/x-yaml'
        # Validate YAML format
        # When updating a NSD, the json object sent to API must contain just data inside
        # of the nsd, without the json field nsd: before
        ns, errors = parse_yaml(request.body.read)
        json_error 400, errors, component, operation, time_req_begin if errors

        # Translate from YAML format to JSON format
        new_ns_json = yaml_to_json(ns)

        # Validate JSON format
        new_ns, errors = parse_json(new_ns_json)
        json_error 400, errors, component, operation, time_req_begin if errors

      else
        # Compatibility support for JSON content-type
        # Parses and validates JSON format
        new_ns, errors = parse_json(request.body.read)
        json_error 400, errors, component, operation, time_req_begin if errors
    end


    platform = if keyed_params.key?(:platform)
                 keyed_params[:platform].downcase
               else
                 '5gtango'
               end

    bool_cond = (platform.eql?('osm') | platform.eql?('onap')) & new_ns.key?('name')
    json_error 400, 'Platform not aligned with format of descriptor', component, operation, time_req_begin if bool_cond


    new_ns, heads = extract_osm_onap(new_ns, platform)

    # Validate NS
    # Check if mandatory fields Vendor, Name, Version are included
    json_error 400, 'NS Vendor not found', component, operation, time_req_begin unless new_ns.key?('vendor')
    json_error 400, 'NS Name not found', component, operation, time_req_begin unless new_ns.key?('name')
    json_error 400, 'NS Version not found', component, operation, time_req_begin unless new_ns.key?('version')

    # Set headers
    case request.content_type
      when 'application/x-yaml'
        headers = { 'Accept' => 'application/x-yaml', 'Content-Type' => 'application/x-yaml' }
      else
        headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
    headers[:params] = params unless params.empty?

    # Retrieve stored version
    if keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      json_error 400, 'Update Vendor, Name and Version parameters are null', component, operation, time_req_begin
    else
      begin
        ns = Nsd.find_by({ 'nsd.vendor' => keyed_params[:vendor], 'nsd.name' => keyed_params[:name],
                          'nsd.version' => keyed_params[:version] })
        logger.cust_debug(component: component, operation: operation, message: "NS is found")
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist", component, operation, time_req_begin
      end
    end
    # Check if NS already exists in the catalogue by Name, Vendor and Version
    begin
      ns = Nsd.find_by({ 'nsd.name' => new_ns['name'], 'nsd.vendor' => new_ns['vendor'],
                         'nsd.version' => new_ns['version'] })
      json_return 200, 'Duplicated NS Name, Vendor and Version', component, operation, time_req_begin
    rescue Mongoid::Errors::DocumentNotFound => e
      # Continue
    end

    username = if keyed_params.key?(:username)
      keyed_params[:username]
    else
      nil
               end

    # Update to new version
    puts 'Updating...'
    new_nsd = {}
    new_nsd['_id'] = SecureRandom.uuid # Unique UUIDs per NSD entries
    new_nsd['nsd'] = new_ns
    new_nsd['platform'] = platform
    new_nsd['header'] = heads if platform.eql?('osm') | platform.eql?('onap')
    new_nsd['status'] = 'active'
    new_nsd['pkg_ref'] = 1
    new_nsd['signature'] = nil
    new_nsd['md5'] = checksum new_ns.to_s
    new_nsd['username'] = username

    # First, Refresh dictionary about the new entry
    update_entr_dict(new_nsd, :nsd)

    # Then, create descriptor
    begin
      new_ns = Nsd.create!(new_nsd)
    rescue Moped::Errors::OperationFailure => e
      json_return 200, 'Duplicated NS ID', component, operation, time_req_begin if e.message.include? 'E11000'
    end
    logger.cust_debug(component: component, operation: operation, message: "NSD #{new_ns}")
    logger.cust_info(status: 200, start_stop: 'STOP', message: "Ended at #{Time.now.utc}", component: component, operation: operation, time_elapsed: "#{Time.now.utc - time_req_begin }")

    # Transform descriptor to appear as OSM body
    new_ns = transform_descriptor(new_ns, type_of_desc='nsd', platform = platform)

    response = case request.content_type
      when 'application/json'
        new_ns.to_json
      else
        json_to_yaml(new_ns.to_json)
               end
    halt 200, {'Content-type' => request.content_type}, response
  end

  # @method update_nss_id
  # @overload put '/catalogues/network-services/:id/?'
  # Update a NS in JSON or YAML format
  ## Catalogue - UPDATE
  put '/network-services/:id/?' do

    # Logger details
    operation = "PUT /v2/network-services?#{params[:id]}"
    component = __method__.to_s
    time_req_begin = Time.now.utc

    logger.cust_info(start_stop:'START', component: component, operation: operation, message: "Started at #{time_req_begin}")

    # Return if content-type is invalid
    json_error 415, 'Support of x-yaml and json', component, operation, time_req_begin unless (request.content_type == 'application/x-yaml' or request.content_type == 'application/json')

    #Delete key "captures" if present
    params.delete(:captures) if params.key?(:captures)

    unless params[:id].nil?

      # Transform 'string' params Hash into keys
      keyed_params = keyed_hash(params)


      # Check for special case (:status param == <new_status>)
      if keyed_params.key?(:status)
        # Do update of Descriptor status -> update_ns_status
        logger.cust_debug(component: component, operation: operation, message: "/v2/network-services/#{query_string}")

        # Validate NS
        # Retrieve stored version
        begin
          ns = Nsd.find_by({ '_id' => params[:id] })
          logger.cust_debug(component: component, operation: operation, message: "NS is found")
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, 'This NSD does not exists', component, operation, time_req_begin
        end

        # Validate new status
        valid_status = %w(active inactive delete)
        if valid_status.include? keyed_params[:status]
          # Update to new status
          begin
            ns.update_attributes(status: keyed_params[:status])
          rescue Moped::Errors::OperationFailure => e
            json_error 400, 'Operation failed', component, operation, time_req_begin
          end
        else
          json_error 400, "Invalid new status #{keyed_params[:status]}", component, operation, time_req_begin
        end
        json_return 200, "Status updated to {#{query_string}}", component, operation, time_req_begin

      else

        # # Retrieve body request
        # json_error 400, "Empty body request", component, operation, time_req_begin if request.body.read.blank?

        # Compatibility support for YAML content-type
        case request.content_type
          when 'application/x-yaml'
            # Validate YAML format
            # When updating a NSD, the json object sent to API must contain just data inside
            # of the nsd, without the json field nsd: before
            ns, errors = parse_yaml(request.body.read)
            json_error 400, errors, component, operation, time_req_begin if errors

            # Translate from YAML format to JSON format
            new_ns_json = yaml_to_json(ns)

            # Validate JSON format
            new_ns, errors = parse_json(new_ns_json)
            json_error 400, errors, component, operation, time_req_begin if errors

          else
            # Compatibility support for JSON content-type
            # Parses and validates JSON format
            new_ns, errors = parse_json(request.body.read)
            json_error 400, errors, component, operation, time_req_begin if errors
        end

        # Retrieve platform from optional parameter
        platform = if keyed_params.key?(:platform)
                     keyed_params[:platform].downcase
                   else
                     '5gtango'
                   end

        bool_cond = (platform.eql?('osm') | platform.eql?('onap')) & new_ns.key?('name')
        json_error 400, 'Platform not aligned with format of descriptor', component, operation, time_req_begin if bool_cond


        new_ns, heads = extract_osm_onap(new_ns, platform )

        # Validate NS
        # Check if mandatory fields Vendor, Name, Version are included
        json_error 400, 'NS Vendor not found', component, operation, time_req_begin unless new_ns.key?('vendor')
        json_error 400, 'NS Name not found', component, operation, time_req_begin unless new_ns.key?('name')
        json_error 400, 'NS Version not found', component, operation, time_req_begin unless new_ns.key?('version')

        # Retrieve stored version
        begin
          ns = Nsd.find_by({ '_id' => params[:id] })
          logger.cust_debug(component: component, operation: operation, message: "NS is found")
        rescue Mongoid::Errors::DocumentNotFound => e
          json_error 404, "The NSD ID #{params[:id]} does not exist", component, operation, time_req_begin
        end

        # Check if NS already exists in the catalogue by name, vendor and version
        begin
          ns = Nsd.find_by({ 'nsd.name' => new_ns['name'], 'nsd.vendor' => new_ns['vendor'],
                             'nsd.version' => new_ns['version'] })
          json_return 200, 'Duplicated NS Name, Vendor and Version', component, operation, time_req_begin
        rescue Mongoid::Errors::DocumentNotFound => e
          # Continue
        end

        username = if keyed_params.key?(:username)
          keyed_params[:username]
        else
          nil
                   end

        # Update to new version
        puts 'Updating...'
        new_nsd = {}
        new_nsd['_id'] = SecureRandom.uuid # Unique UUIDs per NSD entries
        new_nsd['nsd'] = new_ns
        new_nsd['status'] = 'active'
        new_nsd['platform'] = platform
        new_nsd['header'] = heads if platform.eql?('osm') | platform.eql?('onap')
        new_nsd['pkg_ref'] = 1
        new_nsd['signature'] = nil
        new_nsd['md5'] = checksum new_ns.to_s
        new_nsd['username'] = username

        # First, Refresh dictionary about the new entry
        update_entr_dict(new_nsd, :nsd)

        # Then, create descriptor
        begin
          new_ns = Nsd.create!(new_nsd)
        rescue Moped::Errors::OperationFailure => e
          json_return 200, 'Duplicated NS ID', component, operation, time_req_begin if e.message.include? 'E11000'
        end
        logger.cust_debug(component: component, operation: operation, message: "NSD #{new_ns}")
        logger.cust_info(status: 200, start_stop: 'STOP', message: "Ended at #{Time.now.utc}", component: component, operation: operation, time_elapsed: "#{Time.now.utc - time_req_begin }")

        # Transform descriptor in its initial form
        new_ns = transform_descriptor(new_ns, type_of_desc='nsd', platform=platform)

        response = case request.content_type
          when 'application/json'
            new_ns.to_json
          else
            json_to_yaml(new_ns.to_json)
                   end
        halt 200, {'Content-type' => request.content_type}, response
      end
    end
    logger.cust_debug(component: component, operation: operation, message: "No NSD ID specified")
    json_error 400, 'No NSD ID specified', component, operation, time_req_begin
  end

  # @method delete_nsd_sp_ns
  # @overload delete '/network-services/?'
  #	Delete a NS by vendor, name and version
  delete '/network-services/?' do

    # Logger details
    operation = "DELETE /v2/network-services?#{query_string}"
    component = __method__.to_s
    time_req_begin = Time.now.utc

    logger.cust_info(start_stop:'START', component: component, operation: operation, message: "Started at #{time_req_begin}")

    #Delete key "captures" if present
    params.delete(:captures) if params.key?(:captures)

    # Transform 'string' params Hash into keys
    keyed_params = keyed_hash(params)

    unless keyed_params[:vendor].nil? && keyed_params[:name].nil? && keyed_params[:version].nil?
      begin
        ns = Nsd.find_by({ 'nsd.vendor' => keyed_params[:vendor], 'nsd.name' => keyed_params[:name],
                          'nsd.version' => keyed_params[:version]} )
        logger.cust_debug(component: component, operation: operation, message: "NS is found")
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD Vendor #{keyed_params[:vendor]}, Name #{keyed_params[:name]}, Version #{keyed_params[:version]} does not exist", component, operation, time_req_begin
      end
      logger.cust_debug(component: component, operation: operation, message: "NSD #{ns}")

      if ns['pkg_ref'] == 1
        # Referenced only once. Delete in this case
        # Delete entry in dict mapping
        del_ent_dict(ns, :nsd)
        ns.destroy
        json_return 200, 'NSD removed', component, operation, time_req_begin
      else
        # Referenced above once. Decrease counter
        ns.update_attributes(pkg_ref: ns['pkg_ref'] - 1)
        json_return 200, "NSD referenced => #{ns['pkg_ref']}", component, operation, time_req_begin
      end

    end
    logger.cust_debug(component: component, operation: operation, message: "No NSD Vendor, Name, Version specified")
    json_error 400, 'No NSD Vendor, Name, Version specified',component, operation, time_req_begin
  end

  # @method delete_nsd_sp_ns_id
  # @overload delete '/catalogues/network-service/:id/?'
  #	  Delete a NS by its ID
  #	  @param :id [Symbol] unique identifier
  # Delete a NS by uuid
  delete '/network-services/:id/?' do

    # Logger details
    operation = "DELETE /v2/network-services/#{params[:id]}"
    component = __method__.to_s
    time_req_begin = Time.now.utc

    logger.cust_info(start_stop:'START', component: component, operation: operation, message: "Started at #{time_req_begin}")

    unless params[:id].nil?
      begin
        ns = Nsd.find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound => e
        json_error 404, "The NSD ID #{params[:id]} does not exist", component, operation, time_req_begin unless ns
      end
      logger.cust_debug(component: component, operation: operation, message: "NSD #{ns}")

      if ns['pkg_ref'] == 1
        # Referenced only once. Delete in this case
        # Delete entry in dict mapping
        del_ent_dict(ns, :nsd)
        ns.destroy
        json_return 200, 'NSD removed', component, operation, time_req_begin
      else
        # Referenced above once. Decrease counter
        ns.update_attributes(pkg_ref: ns['pkg_ref'] - 1)
        json_return 200, "NSD referenced => #{ns['pkg_ref']}", component, operation, time_req_begin
      end

    end
    logger.cust_debug(component: component, operation: operation, message: "No NSD ID specified")
    json_error 400, 'No NSD ID specified', component, operation, time_req_begin
  end

end