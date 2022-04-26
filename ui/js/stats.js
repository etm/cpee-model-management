var value_count = 100

function stats_update(ename) {
  var iname = ename.replace(/[^a-z0-9A-Z]/g,'-')
  $.get('server/dash/stats/',{ engine: ename },function(data){
    console.log(iname);
    $('#resource_utilization_text_' + iname + ' .total_created').text(data.total_created)
    $('#resource_utilization_text_' + iname + ' .total_finished').text(data.total_finished)
    $('#resource_utilization_text_' + iname + ' .total_abandoned').text(data.total_abandoned)
    $('#resource_utilization_text_' + iname + ' .current_ready').text(data.ready)
    $('#resource_utilization_text_' + iname + ' .current_running').text(data.running)
    $('#resource_utilization_text_' + iname + ' .current_stopped').text(data.stopped)
  });
}

function stats_add(ename) {
  let inode = document.importNode($("#stats_engine")[0].content,true);
  var iname = ename.replace(/[^a-z0-9A-Z]/g,'-')
  $('.stats_title',inode).text($('.stats_title',inode).text() + ename)
  $('.stats_plot',inode).attr('id','resource_utilization_plot_'+iname)
  $('.stats_text',inode).attr('id','resource_utilization_text_'+iname)
  stats_update(ename);

  $('#resource_utilization').append(inode)

  var trace1 = {
    y: Array(value_count).fill(0),
    type: 'scatter',
    name: '% CPU'
  };

  var trace2 = {
    y: Array(value_count).fill(0),
    type: 'scatter',
    name: '% Mem Used'
  };

  var layout = {
    margin: {t:0,r:0,b:0,l:20},
    height: 200,
    width: 700,
    yaxis: {
      range: [-5, 105]
    },
    xaxis: {
      showticklabels: false,
      fixedrange: true
    }
  };

  var data = [trace1, trace2];

  Plotly.newPlot('resource_utilization_plot_' + iname, data, layout, {displayModeBar: false});
}


function stats_init() {
  let es = new EventSource('server/dash/events/');
  let count = {};
  es.onopen = function() {
    console.log('stats open');
  };
  es.onmessage = function(e) {
    let data = JSON.parse(e.data)
    if (data.topic == "node" && data.event == "resource_utilization") {
      const iname = data.engine.replace(/[^a-z0-9A-Z]/g,'-')
      if ($('#resource_utilization_plot_' + iname).length == 0) {
        stats_add(data.engine);
        count[data.engine] = value_count;
      }
      count[data.engine]++
      Plotly.extendTraces('resource_utilization_plot_' + iname, {y: [[data.cpu_usage], [(data.mem_total-data.mem_available)/data.mem_total * 100]]}, [0,1])
      Plotly.relayout('resource_utilization_plot_' + iname, {
        xaxis: {
          range: [count[data.engine]-value_count,count[data.engine]],
          showticklabels: false,
          fixedrange: true
        }
      });
    } else if (data.topic == "state" && data.event == "change") {
      stats_update(data.engine);
    } else {
      console.log(data);
    }
  };
  es.onerror = function() {
    console.log('stats error');
  }
}

$(document).ready(function() {
  stats_init();
});
