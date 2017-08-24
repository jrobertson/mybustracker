#!/usr/bin/env ruby

# file: mybustracker.rb

require 'savon'
require 'digest'

class MyBusTrackerException < Exception
end

class MyBusTracker


  def initialize(api_key: '')


    raise MyBusTrackerException, 'api_key missing' if api_key.empty?

    @client = Savon.client(wsdl: 'http://ws.mybustracker.co.uk/?wsdl')

    #@client.operations

    #=> [:get_topo_id, :get_services, :get_service_points, :get_dests, 
    #    :get_bus_stops, :get_bus_times, :get_journey_times, :get_disruptions, 
    #    :get_diversions, :get_diversion_points]  

    @appkey = Digest::MD5.hexdigest( api_key + Time.now.strftime("%Y%m%d%H"))


  end

  def services()

    # call the get_services operation
    response = @client.call(:get_services, message: { key: @appkey  })
    r = response.body

    a = r[:services_response][:services][:list].map do |x| 
      [x[:mnemo], x[:name]]
    end

    a.to_h

  end
end

