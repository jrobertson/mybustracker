# Introducing the MyBusTracker gem


    require 'mybustracker'

    mbt = MyBusTracker.new api_key: '*secret API key *'

    service = mbt.service '44'

    service.bus_stops

Output:
<pre>
[
 "Whitecraig", "Whitecraig Ave", "Wallyford Termin", "Wallyford Termin", 
 "Wallyford Loan", "Wallyford P&R", "Macbeth Moir", "Macbeth Moir", 
 "Macbeth Moir", "Pinkie Mains", "Edenhall Road", "Park Lane", "King Street",
 "Brunton Theatre", "The Ship Inn", "Edinburgh Road", "Eastfield Garden", 
 "Milton Terrace", "Portobello Cemet", "Brunstane Bank", "Duddingston Hous", 
 "Duddingston Mill", "Northfield Terra", "Northfield Terra", "Abercorn Road",
 "Meadowbank House", "Meadowbank Stadi", "Wishaw Terrace", "Marionville Road",
 "[EC] Leopold Pla", "[PT] Princes Str", "[SF] Shandwick P", "Dalry Primary Sc",
 "Moat Drive", "Slateford Stn", "Hailes Avenue", "Hailes Avenue", "Spylaw Park", 
 "Juniper Green Ch", "Baberton Avenue", "Muirwood Road", "Nether Currie", 
 "Curriehill", "Stewart Road", "Lanark Road End", "Lovedale Road", "Thriepmuir"
]
</pre>

    r = service.query from: "Jock's Lodge", to: 'Dalry Road'

Output:
<pre>
{
  :from=>{
    :bus_stop=>"Meadowbank House", 
    :bus_stop_id=>"36234737", 
    :times=>["9:37pm", "10:09pm"]
  }, 
  :to=>{
    :bus_stop=>"Caledonian Villa", 
    :bus_stop_id=>"36232672", 
    :times=>["10:00pm", "10:32pm"]
  }, 
  :stops=>[
    "Meadowbank House", "Meadowbank Stadi", "Wishaw Terrace", "Marionville Road", 
    "Abbeyhill", "Brunton Place", "Wellington Stree", "Brunswick Street", 
    "[EC] Leopold Pla", "[YB] York Place", "[YC] North St Da", "[PT] Princes Str",
    "[PY] Princes Str", "[SF] Shandwick P", "[SG] Atholl Cres", "[HG] Haymarket", 
    "Caledonian Villa"
  ], 
  :start=>"9:37pm", :end=>"10:00pm", :travel_time=>"~23 minutes"
} 
</pre>

## Resources

* mybustracker https://rubygems.org/gems/mybustracker

lothianbuses bus mybustracker gem travel times 
