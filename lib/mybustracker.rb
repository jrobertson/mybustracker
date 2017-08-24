#!/usr/bin/env ruby

# file: mybustracker.rb

require 'savon'
require 'digest'
require 'subunit'
require 'geocoder'
require 'geodesic'


class MyBusTrackerException < Exception
  
  class Service < Exception
  end

end


class MyBusTracker
  
  class Service
    
    attr_reader :ref, :operator, :number, :name, :bus_stops
    
    def initialize(client, appkey, service, all_dests, 
                   all_bus_stops, number='')
      
      if number.empty? then
        raise MyBusTrackerException::Service, 'provide a bus service number'
      end
      
      @client, @appkey = client, appkey
      
      # find out the reference number from the service hash object      

      #e.g. => {:ref=>"7", :operator_id=>"LB", :mnemo=>"4", :name=>"The Jewel
      #-- Hillend", :type=>nil, :dests=>{:list=>["458752", ...]}
      
      @number, @name, @ref, relative_dests, operator  = \
          %i(mnemo name ref dests operator).map {|field| service[field]}
      
      @all_bus_stops = all_bus_stops

      
    end
    
    # accepts a bus service number and returns the relative bus times
    #
    def query(times: 'next hour', from: nil, to: nil)
      
      #from ||=
      
      start_bus_stop1, start_bus_stop2 = find_bus_stop(from)
      end_bus_stop1, end_bus_stop2 = find_bus_stop(to)
      
      # get the bus times
      
      @bus_stops, journey_times = get_stop_journeys(start_bus_stop1)

      # select the bus stop end
      
      end_stop = journey_times.find do |x| 
        x[:stop_id] == end_bus_stop1[:stop_id] or x[:stop_id] == end_bus_stop2[:stop_id]
      end
            
      if end_stop then
        start_bus_stop = start_bus_stop1
      else
        start_bus_stop = start_bus_stop2
        @bus_stops, journey_times = get_stop_journeys(start_bus_stop2) unless end_stop
        return unless @bus_stops
        # select the bus stop end

        end_stop = journey_times.find do |x|
          (x[:stop_id] == end_bus_stop1[:stop_id]) or (x[:stop_id] == end_bus_stop2[:stop_id])
        end
        
      end

      tstart = Time.strptime(journey_times[0][:time],"%H:%M")
      tend = Time.strptime(end_stop[:time],"%H:%M")
      travel_time = '~' + Subunit.new(units={minutes:60, hours:60}, \
                                 seconds: tend - tstart).to_s(omit: [:seconds])
      
      {
        from: {bus_stop: start_bus_stop[:name], bus_stop_id: start_bus_stop[:stop_id]},
        to: {bus_stop: end_stop[:stop_name], bus_stop_id: end_stop[:stop_id]},
        start: journey_times[0][:time], 
        end: end_stop[:time],
        travel_time: travel_time
      }
      
    end
    
    private    
    
    def find_bus_stop(address)
      
      results = Geocoder.search(address.sub(/,? *edinburgh$/i,'') \
                                + ", Edinburgh")
      
      p1    = Geodesic::Position.new(*results[0].coordinates)

      a = @all_bus_stops.sort_by do |h|
        
        x, y = %i(x y).map {|fields| h[fields].to_f.round(4)}

        p2 = Geodesic::Position.new(x, y)
        d = Geodesic::dist_haversine(p1.lat, p1.lon, p2.lat, p2.lon).round(4)
      end
      a.take 2
            
    end
    
    def get_stop_journeys(start_bus_stop)
      
      response = @client.call(:get_bus_times, message: { key: @appkey, time_requests: {list: [{stop_id: start_bus_stop[:stop_id] }]} })
      
      bus_times = response.body[:bus_times_response][:bus_times][:list].find do |bus_time|
        bus_time[:ref_service] == @ref
      end
      
      #e.g.r.keys  => [:operator_id, :stop_id, :stop_name, :ref_service, :mnemo_service, :name_service, 
      # :time_datas, :global_disruption, :service_disruption, :bus_stop_disruption, :service_diversion]
      
      return unless bus_times
      
      # get the 1st journey id
      list = bus_times[:time_datas][:list]
      journey_id = list.is_a?(Array) ? list[0][:journey_id] : list[:journey_id]
      
      response = @client.call(:get_journey_times, message: { key: @appkey, journey_id: journey_id,  stop_id: start_bus_stop[:stop_id]  })
      journey = response.body[:journey_times_response][:journey_times][:list]
#=> [:journey_id, :bus_id, :operator_id, :ref_service, :mnemo_service, :name_service, :ref_dest, :name_dest, :terminus, :journey_time_datas, :global_disruption, :service_disruption, :service_diversion] 

      journey_times = journey[:journey_time_datas][:list]
      # get the bus stops
      [journey_times.inject({}) {|r,x| r.merge(x[:stop_name] => {id: x[:stop_id]}) }, journey_times]
    end
    
    # method no longer used
    #
    def fetch_bus_stops2()
      # find the outbound destination
      dest = relative_dests[:list].find do |ref|
        all_dests.find {|x| x[:ref] == ref and x[:direction] == 'R' }
      end      
      
      # go through each bus stop to find the dests

      raw_bus_stops = all_bus_stops.select do |bus_stop|
        bus_stop[:dests][:list].include? dest
      end

      c = ->(coord){ coord.to_f.round(4)}      
      
      response = client.call(:get_service_points, message: \
                             { key: appkey, ref: ref  })
      all_service_points = response.body[:service_points_response]\
          [:service_points][:list]      
      
      # select only the 1st chain
      #service_points = all_service_points#.group_by {|x| x[:chainage]}.first[-1]
      #puts 'service_points: ' + service_points.inspect
      
      unsorted_bus_stops = []
      raw_bus_stops.each do |bus_stop|

        x, y = %i(x y).map {|field| bus_stop[field]}.map(&c)

        r = all_service_points.select do |point|
          [point[:x], point[:y]].map(&c) == [x, y]
        end

        r.each do |x|
          unsorted_bus_stops << [bus_stop[:name], bus_stop[:stop_id], x, x[:order].to_i ]
        end

      end

      
      #@bus_stops = unsorted_bus_stops.compact.sort_by(&:last)
#=begin      
      # find the correct chainage by the most records
      h = unsorted_bus_stops.group_by {|x| x[2][:chainage]}
      a = h.map {|k,v| v.count {|x| x[2][:chainage] == k}}      
      
      @bus_stops = h.to_a[a.index(a.max)].last\
          .sort_by(&:last).inject({}){|r, x| r.merge(x[0] => {id: x[1]}) }
#=end            
    end
    
  end


  def initialize(api_key: '')


    raise MyBusTrackerException, 'api_key missing' if api_key.empty?

    @client = client = Savon.client(wsdl: 'http://ws.mybustracker.co.uk/?wsdl')

    #@client.operations

    #=> [:get_topo_id, :get_services, :get_service_points, :get_dests, 
    #    :get_bus_stops, :get_bus_times, :get_journey_times, :get_disruptions, 
    #    :get_diversions, :get_diversion_points]  

    @appkey = appkey = Digest::MD5.hexdigest( api_key + 
                                              Time.now.strftime("%Y%m%d%H"))
    
    response = client.call(:get_services, message: { key: appkey  })
    @all_services= response.body[:services_response][:services][:list]
    
    response = client.call(:get_dests, message: { key: appkey  })
    @all_dests = response.body[:dests_response][:dests][:list]
    
    response = client.call(:get_bus_stops, message: { key: appkey  })
    @all_bus_stops = response.body[:bus_stops_response][:bus_stops][:list]


  end

  # returns the number and name of all bus services
  #
  def services()

    @all_services.map {|x| [x[:mnemo], x[:name]] }.to_h

  end
  
  # accepts a bus service number and returns the relative bus times
  #
  def service(number='')
    
    service = @all_services.find {|x| x[:mnemo] == number }        
    Service.new @client, @appkey, service, @all_dests, @all_bus_stops, number
    
  end
    
  
end
