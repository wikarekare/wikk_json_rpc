require_relative 'rpc.rb'
require 'json'

# { //Json-rpc example
#     "method"  : "X.sum", //In our case, this is class.rmethod. Class may be 1:1 to an SQL table, or do random stuff.
#     "params"  :  { "a": 17, "b": 25 }, //optional in alt mode. (Which we will use, to explicitly name parametres)
#     "jsonrpc" : "2.0", // version of the json rpc standard. (Which we are likely to be breaking)
#     "id": 12345 //optional, and returned to caller if present.
# }
# { //success.
#   "result"  :  { "value": 42 }, //Format is call dependent
#   "jsonrpc" : "2.0", // version of the json rpc standard. (Which we are likely to be breaking)
#   "id": 12345 //returned if call sends id (ie. it is the callers reference)
# }
# { //failure.
#   "error" : {
#        "code" : 123,
#        "message" : "An error occurred parsing the request object.",
#        "error" : {
#            "message" : "Bad array",
#            "at" : 42,
#            "text" : "{\"id\":1,\"method\":\"sum\",\"params\":[1,2,3,4,5}"
#
#            }
#        }
#   }
#   "jsonrpc" : "2.0",
#   "id": 12345 //returned if call sends id
# }
#
# //Local addition, defining the use of tags in kwparams. These map to SQL queries
# //allowing a random query, within the bounds set by the RPC handler.
# "kwparams"  : {
#   select_on: {key: value, key: value, ...},     //optional columns to select rows with.
#   set: {key: value, key: value, ...},           //optional values to set in an update
#   result: [key,key,key,...]                     //result filter for set of columns to return.
# }
#
class Json_RPC
  def json_to_rpc(json_str)
    begin
      RPC.rpc( json_str.to_h ).to_json
    rescue Exception => _e # rubocop:disable Lint/RescueException -- (don't want this to fail, for any reason)
      # puts "Json_RPC Failed with: #{e}"
    end
  end
end
