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
    
    def initialize(client, appkey, mbt,  service, number='')
      
      if number.empty? then
        raise MyBusTrackerException::Service, 'provide a bus service number'
      end
      
      @client, @appkey, @mbt = client, appkey, mbt
      
      @number, @name, @ref, relative_dests, operator  = \
          %i(mnemo name ref dests operator).map {|field| service[field]}      
      
      Thread.new{ fetch_bus_stops() }
      
    end
    
    def inspect()
      "<#<MyBusTracker::Service:%s @number=\"%s\">" % [self.object_id, @number]
    end    
    
    # accepts a bus service number and returns the relative bus times
    #
    def query(times: 'next hour', from: nil, to: nil)
      
      #from ||=
      
      start_bus_stop1, start_bus_stop2 = find_bus_stop(from)
      end_bus_stop1, end_bus_stop2 = find_bus_stop(to)

      # get the bus times
      
      bus_times = get_bus_times(start_bus_stop1)            
      
      journey_times = get_stop_journeys(start_bus_stop1, bus_times, index: 0)
      return unless journey_times

      # select the bus stop end
      
      end_stop = journey_times.find do |x| 
        x[:stop_id] == end_bus_stop1[:stop_id] or 
            x[:stop_id] == end_bus_stop2[:stop_id]
      end
      
            
      if end_stop then
        start_bus_stop = start_bus_stop1
      else
        start_bus_stop = start_bus_stop2
        bus_times = get_bus_times(start_bus_stop2)
        
        unless end_stop
          journey_times = get_stop_journeys(start_bus_stop2, bus_times)
        end
        
        return unless journey_times
        # select the bus stop end

        end_stop = journey_times.find do |x|
          (x[:stop_id] == end_bus_stop1[:stop_id]) or 
              (x[:stop_id] == end_bus_stop2[:stop_id])
        end
        
      end
      
      stop_id = end_stop[:stop_id]      
      
      # get the other journeys
      # still todo
      journeys = [[journey_times[0][:time], end_stop[:time]]]
      journey = get_stop_journeys(start_bus_stop, bus_times, index: 1)      
      
      if journey then
        end_stop = journey.find {|x| x[:stop_id] == stop_id }

        journeys << [journey[0][:time], end_stop[:time]] 
      end
      
      # get the journeys for the given period
      #secs = journeys[1][0][:time] - journey_times[0][:time]
      
      from_times = journeys.map {|x| Time.strptime(x.first, "%H:%M").strftime("%-I:%M%P")}
      to_times = journeys.map {|x| Time.strptime(x.last, "%H:%M").strftime("%-I:%M%P")}

      tstart = Time.strptime(journeys[0][0],"%H:%M")
      tend = Time.strptime(journeys[0][-1],"%H:%M")
      travel_time = '~' + Subunit.new(units={minutes:60, hours:60}, \
                                 seconds: tend - tstart).to_s(omit: [:seconds])
      
      index = journey_times.index journey_times.find {|x| x[:stop_id] == stop_id}
      stops = journey_times[0..index].map {|x| x[:stop_name] }
      
      {
        from: {bus_stop: start_bus_stop[:name], bus_stop_id: 
               start_bus_stop[:stop_id], times: from_times},
        to: {bus_stop: end_stop[:stop_name], bus_stop_id: end_stop[:stop_id], 
             times: to_times},
        stops: stops ,
        start: tstart.strftime("%-I:%M%P"), 
        end: tend.strftime("%-I:%M%P"),
        travel_time: travel_time
      }
      
    end
    
        
    private    
    
    def find_bus_stop(address)
      
      @mbt.find_nearest_stops(address, limit: 2).map(&:first)
            
    end
    

    def get_bus_times(start_bus_stop)
      
      response = @client.call(:get_bus_times, message: { key: @appkey, 
               time_requests: {list: [{stop_id: start_bus_stop[:stop_id] }]} })
      
      response.body[:bus_times_response][:bus_times][:list].find do |bus_time|
        bus_time[:ref_service] == @ref
      end      
    end
    
    def get_stop_journeys(start_bus_stop, bus_times, index: 0)
      
      
      return unless bus_times
      
      # get the 1st journey id
      list = bus_times[:time_datas][:list]
           
      journey_id = list.is_a?(Array) ? list[index][:journey_id] : \
                      list[:journey_id]    
      response = @client.call(:get_journey_times, message: { key: @appkey, 
                 journey_id: journey_id,  stop_id: start_bus_stop[:stop_id]  })

      return unless response.body[:journey_times_response][:journey_times]
      
      journey = response.body[:journey_times_response][:journey_times][:list]

      journey_times = journey[:journey_time_datas][:list]
                                             
      return journey_times
    end
    
    # returns all bus stops for outbound route ("R")
    #
    def fetch_bus_stops()
      
      client, appkey, ref = @client, @appkey, @ref
      
      response = client.call(:get_dests, message: { key: appkey  })
      r = response.body

      response = client.call(:get_bus_stops, message: { key: appkey  })
      all_bus_stops = response.body[:bus_stops_response][:bus_stops][:list]

      r[:dests_response][:dests][:list][0].keys
      #=> [:ref, :operator_id, :name, :direction, :service] 

      dest = r[:dests_response][:dests][:list].find do |d|
        d[:service] == ref and d[:direction] == 'R'
      end

      raw_bus_stops = all_bus_stops.select do |bus_stop|
        bus_stop[:dests][:list].include? dest[:ref]
      end

      c = ->(coord){ coord.to_f.round(4)}      

      response = client.call(:get_service_points, message: \
                            { key: appkey, ref: ref  })
      all_service_points = response.body[:service_points_response]\
          [:service_points][:list]      

      unsorted_bus_stops = []
      raw_bus_stops.each do |bus_stop|

        x, y = %i(x y).map {|field| bus_stop[field]}.map(&c)

        r = all_service_points.select do |point|
          [point[:x], point[:y]].map(&c) == [x, y]
        end

        r.each do |x|
          unsorted_bus_stops << [bus_stop[:name], 
                                 bus_stop[:stop_id], x, x[:order].to_i ]
        end

      end
          
      # find the correct chainage by the most records
      h = unsorted_bus_stops.group_by {|x| x[2][:chainage]}
      a = h.map {|k,v| v.count {|x| x[2][:chainage] == k}}      

      @bus_stops = h.to_a[a.index(a.max)].last.sort_by(&:last).map(&:first)
      
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
    
    response = client.call(:get_bus_stops, message: { key: appkey  })
    @all_bus_stops = response.body[:bus_stops_response][:bus_stops][:list]

  end
  
  def find_nearest_stops(address, limit: 4)

    results = Geocoder.search(address.sub(/,? *edinburgh$/i,'') \
                              + ", Edinburgh")
    
    p1    = Geodesic::Position.new(*results[0].coordinates)

    a = @all_bus_stops.map do |h|
      
      x, y = %i(x y).map {|fields| h[fields].to_f.round(4)}

      p2 = Geodesic::Position.new(x, y)
      d = Geodesic::dist_haversine(p1.lat, p1.lon, p2.lat, p2.lon).round(4)
      [h,d]
    end
    
    a.sort_by(&:last).take limit

  end

  alias nearest_stops find_nearest_stops

  def inspect()
    "<#<MyBusTracker:%s>" % [self.object_id]
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
    Service.new @client, @appkey, self, service,  number
    
  end            
  
end
