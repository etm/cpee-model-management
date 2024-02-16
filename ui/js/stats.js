var value_count = 100

function resource_update(ename) {
  var iname = ename.replace(/[^a-z0-9A-Z]/g,'-').replace(/-$/,'')
  $.get('server/dash/stats/',{ engine: ename },function(data){
    $('#resource_utilization_text_' + iname + ' .total_created').text(data.total_created)
    $('#resource_utilization_text_' + iname + ' .total_finished').text(data.total_finished)
    $('#resource_utilization_text_' + iname + ' .total_abandoned').text(data.total_abandoned)
    $('#resource_utilization_text_' + iname + ' .current_ready').text(data.ready)
    $('#resource_utilization_text_' + iname + ' .current_running').text(data.running)
    $('#resource_utilization_text_' + iname + ' .current_stopped').text(data.stopped)
  });
}

function resource_add(ename) {
  let inode = document.importNode($("#stats_engine")[0].content,true);
  var iname = ename.replace(/[^a-z0-9A-Z]/g,'-').replace(/-$/,'')
  $('.stats_title',inode).text($('.stats_title',inode).text() + ename)
  $('.stats_plot',inode).attr('id','resource_utilization_plot_'+iname)
  $('.stats_text',inode).attr('id','resource_utilization_text_'+iname)

  $('#resources').append(inode)

  resource_update(ename);

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

function instance_change(d) {
  const ename = d.engine
  const iname = d.engine.replace(/[^a-z0-9A-Z]/g,'-').replace(/-$/,'')

  if (d.state == "ready") {
    if ($('[data-id=' + d.uuid + ']').length > 0) {
      if ($('[data-id=' + d.uuid + ']').attr('data-parent') != parent) {
        $('[data-id=' + d.uuid + ']').remove()
        instance_add(iname,d.uuid,d.url,d.name,d.state,d.author,0,0,d.parent)
      } else {
        instance_upd(d.uuid,d.name,d.state,d.author,0,0,d.parent)
      }
    } else {
      instance_add(iname,d.uuid,d.url,d.name,d.state,d.author,0,0,d.parent)
    }
  } else if (d.state == 'abandoned' || d.state == 'finished') {
    if ($('tr.sub[data-id=' + d.uuid + '] > td > table > tr').length > 0) {
      $('tr.text[data-id=' + d.uuid + ']').replaceWith($('tr.sub[data-id=' + d.uuid + '] > td > table > tr'))
    }
    $('[data-id=' + d.uuid + ']').remove()
    instances_striping(iname)
  } else {
    if ($('tr.sub[data-id=' + d.uuid + ']').attr('data-parent') != d.parent) {
      $('[data-id=' + d.uuid + ']').remove()
      instance_add(iname,d.uuid,d.url,d.name,d.state,d.author,0,0,d.parent)
    } else {
      instance_upd(d.uuid,d.name,d.state,d.author,0,0,d.parent)
    }
  }
}

function instance_upd(uuid,name,state,author,cpu,mem,parent) {
  if (name != "") {
    $('[data-id=' + uuid + '] > .name a').text(name)
    $('[data-id=' + uuid + '] > .name a').attr('title',name)
  }
  $('[data-id=' + uuid + '] > .state span.value').text(state)
  $('[data-id=' + uuid + '] > .state').attr('data-state',state)
  if (author != "") {
    $('[data-id=' + uuid + '] > .author').text(author)
  }
  instance_res(uuid,cpu,mem)
}
function instance_res(uuid,cpu,mem) {
  $('[data-id=' + uuid + '] > .cpu').text($.sprintf('%05.2f',cpu))
  $('[data-id=' + uuid + '] > .mem').text($.sprintf('%05.2f',mem))
}
function instance_add(iname,uuid,url,name,state,author,cpu,mem,parent) {
  let inode = document.importNode($("#stats_instance")[0].content,true);
  $('.sub',inode).attr('id',uuid)
  $('.sub',inode).attr('data-id',uuid)
  $('.sub',inode).attr('data-parent',parent)
  $('.text',inode).attr('data-id',uuid)
  $('.text',inode).attr('data-url',url)
  $('.name a',inode).attr('href','server/dash/show?url=' + url)
  $('.num span',inode).text(url.split(/[\\/]/).pop())
  if (name != "") {
    $('.name a',inode).text(name)
    $('.name a',inode).attr('title',name)
  }
  $('.state span.value',inode).text(state)
  $('.state',inode).attr('data-state',state)
  if (author != "") {
    $('.author',inode).text(author)
  }
  $('.cpu',inode).text($.sprintf('%05.2f',cpu))
  $('.mem',inode).text($.sprintf('%05.2f',mem))
  if (parent == "") {
    $('#instances_' + iname).append(inode)
  } else {
    $('#' + parent + ' > td > table').append(inode)
  }
  instances_striping(iname)
}

function instances_striping(iname) {
  let even = true
  $('#instances_' + iname + ' tr.text').removeClass('even')
  $('#instances_' + iname + ' tr.text').each((i,e)=>{
    if (even) {
      $(e).addClass('even')
    }
    even = (even == true ? false : true)
  })
}

function timer(ms) { return new Promise(res => setTimeout(res, ms)); }

function instances_init(ename) {
  const iname = ename.replace(/[^a-z0-9A-Z]/g,'-').replace(/-$/,'')
  let inode = document.importNode($("#stats_instances")[0].content,true);
  $('.stats_title',inode).text($('.stats_title',inode).text() + ename)
  $('table',inode).attr('id','instances_'+iname)
  $('#instances').append(inode)
  $.ajax({
    type: "GET",
    url: 'server/dash/instances',
    data: { engine: ename },
    success: (result) => {
      $('instance',result).each(async (i,ele)=>{
        const e = $(ele);
        setTimeout(()=>{instance_add(iname,e.attr('uuid'),e.attr('url'),e.attr('name'),e.attr('state'),e.attr('author'),e.attr('cpu'),e.attr('mem'),e.attr('parent'))},0)
      })
    }
  })
}

function resource_paint(iname,data,count) {
  count[iname]++
  Plotly.extendTraces('resource_utilization_plot_' + iname, {y: [[data.cpu_usage], [(data.mem_total-data.mem_available)/data.mem_total * 100]]}, [0,1])
  Plotly.relayout('resource_utilization_plot_' + iname, {
    xaxis: {
      range: [count[iname]-value_count,count[iname]],
      showticklabels: false,
      fixedrange: true
    }
  });
}

function stats_init() {
  let es = new EventSource('server/dash/events/');
  let count = {};
  es.onopen = function() {
    console.log('stats open');
  };
  es.onmessage = function(e) {
    let data = JSON.parse(e.data)
    const iname = data.engine.replace(/[^a-z0-9A-Z]/g,'-').replace(/-$/,'')
    if ($('#instances').length > 0) {
      if ($('#instances_' + iname).length == 0) {
        instances_init(data.engine);
      }
    }
    if (data.topic == "node" && data.event == "resource_utilization") {
      if ($('#resources').length > 0) {
        if ($('#resource_utilization_plot_' + iname).length == 0) {
          resource_add(data.engine);
          count[iname] = value_count;
        }
        resource_paint(iname,data,count)
      }
    } else if (data.topic == "state" && data.event == "change") {
      if ($('#resources').length > 0) {
        resource_update(data.engine)
      }
      if ($('#instances').length > 0) {
        instance_change(data)
      }
    } else if (data.topic == "status" && data.event == "resource_utilization") {
      if ($('#instances').length > 0) {
        instance_res(data.uuid,data.cpu,data.mem)
      }
    } else {
      console.log(data);
    }
  };
  es.onerror = function() {
    console.log('stats error');
    setTimeout(function(){ if (es.readyState == 2) { stats_init() } }, 5000);
  }
}

$(document).ready(function() {
  stats_init();
  $('#instances').on('click','.abandon',function(e){
    const par = $(e.target).parents('[data-url]').first()
    $.ajax({
      type: "PUT",
      url: 'server/dash/abandon',
      data: { url: par.attr('data-url') }
    })
  })
});
