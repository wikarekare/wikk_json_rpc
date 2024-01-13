var wikk_echo = ( function() {
  var registered_local_completion = null;
  var result = {
    remote_addr: "",
    response: "",
    messages: "Not run yet"
  };

  function get_echo_error(jqXHR, textStatus, errorMessage) {   //Called on failure
  }

  function get_echo_completion(data) {   //Called when everything completed, including callback.
    if(registered_local_completion != null) {
      registered_local_completion(result);
    }
  }

  function get_echo_callback(data) {   //Called when we get a response.
    if(data != null && data.result != null) {
      result = data.result
    } else {
      result.remote_addr = "";
      result.response = "";
      result.messages = "Null result";
    }
  }

  function get_echo(message, local_completion, delay = null) {
    if(delay == null) delay = 0;
    registered_local_completion = local_completion;

    var args = {
      "method": "RPC_Echo.echo",
      "params": {
        "select_on": { "message": message },
        "set": {},
        "result": ["response"]
      },
      "id": Date.getTime(),
      "jsonrpc": 2.0
    }

    url = RPC
    wikk_ajax.delayed_ajax_post_call(url, args, get_echo_callback, get_echo_error, get_echo_completion, 'json', true, delay);
    return false;
  }

  function get_last_echo() {
    return result.response;
  }

  //return a hash of key: function pairs, with the key being the same name as the function.
  //Hence call with wikk_elevation.function_name()
  return {
    get_echo: get_echo,
    get_last_echo: get_last_echo
  };
})();
