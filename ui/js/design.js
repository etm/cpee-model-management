var gstage;
var gdir;

function move_it(name,todir) {
  $.ajax({
    type: "PUT",
    url: "server/" + gdir + name,
    data: { dir: todir }
  });
}
function shift_it(name,to) {
  $.ajax({
    type: "PUT",
    url: "server/" + gdir + name,
    data: { stage: to }
  });
}
function rename_it(name) {
  var newname;
  if (newname = prompt('New name please!',name.replace(/\.xml$/,'').replace(/\.dir$/,''))) {
    $.ajax({
      type: "PUT",
      url: "server/" + gdir + name,
      data: { new: newname }
    });
  }
}
function duplicate_it(name) {
  var newname;
  if (newname = prompt('New name please!',name.replace(/\.xml$/,'').replace(/\.dir$/,''))) {
    $.ajax({
      type: "POST",
      url: "server/" + gdir,
      data: { new: newname, old: name }
    });
  }
}
function delete_it(name) {
  if (confirm('Are you really, really, REALLY sure!')) {
    $.ajax({
      type: "DELETE",
      url: "server/" + gdir + name
    });
  }
}

function es_init(gdir,gstage) {
  var es = new EventSource('server/');
  es.onopen = function() {
    console.log('es open');
  };
  es.onmessage = function(e) {
    paint(gdir,gstage);
  };
  es.onerror = function() {
    console.log('es error');
    // es_init();
  };
}

function paint(gdir,gstage) {
  $('#models tbody').empty();
  if (gdir && gdir != '') {
    var clone = document.importNode(document.querySelector('#up').content,true);
    $('[data-class=name] a',clone).text('..');
    $('[data-class=name] a',clone).attr('href',window.location.pathname + '?stage=' + gstage + '&dir=');
    $('#models tbody').append(clone);
  }
  $.ajax({
    type: "GET",
    url: "server/" + gdir,
    data: { stage: gstage },
    success: function(res) {
      $(res).each(function(k,data) {
        if (data.type == 'dir') {
          var clone = document.importNode(document.querySelector('#folder').content,true);
          $('[data-class=name] a',clone).text(data['name'].replace(/\.dir$/,''));
          $('[data-class=name]',clone).attr('data-full-name',data['name']);
          $('[data-class=name] a',clone).attr('href',window.location.pathname + '?stage=' + gstage + '&dir=' + data['name']);
        } else {
          var clone = document.importNode(document.querySelector('#model').content,true);
          $('[data-class=name] a',clone).text(data['name']);
          $('[data-class=name]',clone).attr('data-full-name',data['name']);
          $('[data-class=name] a',clone).attr('href','server/' + gdir + data['name'] + '/open?stage=' + gstage);
          $('[data-class=force] a',clone).attr('href','server/' + gdir + data['name'] + '/open-new?stage=' + gstage);
          $('[data-class=raw] a',clone).attr('href','server/' + gdir + data['name']);
        }
        $('[data-class=author]',clone).text(data['author']);
        $('[data-class=date]',clone).text(new Date(data['date']).strftime('%Y-%m-%d, %H:%M:%S'));
        $('#models tbody').append(clone);
      });
    }
  });
}

function change_it(gdir,gstage) {
  window.location.href = window.location.pathname + '?stage=' + gstage + '&dir=' + gdir;
}

$(document).ready(function() {
  const queryString = window.location.search;
  const urlParams = new URLSearchParams(queryString);

  gstage = urlParams.get('stage') || 'draft';
  gdir = urlParams.get('dir') ? (urlParams.get('dir') + '/').replace(/\/+/,'/') : '';

  es_init(gdir,gstage);

  var shifts = []
  $.ajax({
    type: "GET",
    url: "server/",
    data: { stages: 'stages' },
    success: (r) => {
      shifts = shifts.concat(r);
      shifts = shifts.filter(item => item !== gstage);
    }
  });

  $('input[name=stage]').val(gstage);
  $('input[name=dir]').val(gdir);
  $('ui-behind span').text(gstage);
  $('ui-behind span').click((e) => {
    if (shifts.length > 0) {
      var menu = {};
      menu['Change to'] = [];
      shifts.forEach(ele => {
        menu['Change to'].push(
          {
            'label': ele,
            'function_call': change_it,
            'text_icon': '➔',
            'type': undefined,
            'class': 'capitalized',
            'params': [gdir,ele]
          }
        );
      });
      new CustomMenu(e).contextmenu(menu);
    }
  });

  var dragged;
  $('#models').on('drag','td[data-class=model]',false);
  $('#models').on('dragstart','td[data-class=model]',(e) => {
    dragged = $(e.currentTarget).parents('tr').find('td[data-class=name]').text();
  });
  $('#models').on('dragover','td[data-class=folder]',false);
  $('#models').on('drop','td[data-class=folder]',(e) => {
    e.preventDefault();
    e.stopPropagation();
    if (dragged) {
      var todir = $(e.currentTarget).parents('tr').find('td[data-class=name]').text();
      todir = todir.replace(/\./g,'');
      if (todir != '') {
        todir += '.dir';
      }
      move_it(dragged,todir);
      dragged = undefined;
    }
  });
  $('#models').on('click','td[data-class=ops]',(e) => {
    var menu = {};
    var name = $(e.currentTarget).parents('tr').find('td[data-class=name]').attr('data-full-name');
    menu['Operations'] = [
      {
        'label': 'Delete',
        'function_call': delete_it,
        'text_icon': '❌',
        'type': undefined,
        'params': [name]
      },
      {
        'label': 'Rename',
        'function_call': rename_it,
        'type': undefined,
        'text_icon': '📛',
        'params': [name]
      }
    ];
    if (name.match(/\.xml$/)) {
      menu['Operations'].unshift(
        {
          'label': 'Duplicate',
          'function_call': duplicate_it,
          'text_icon': '➕',
          'type': undefined,
          'params': [name]
        }
      );
    }
    if (shifts.length > 0) {
      menu['Shifting'] = [];
      shifts.forEach(ele => {
        menu['Shifting'].push(
          {
            'label': 'Shift to ' + ele,
            'function_call': shift_it,
            'text_icon': '➔',
            'type': undefined,
            'params': [name,ele]
          }
        );
      });
    }
    new CustomMenu(e).contextmenu(menu);
  });

  history.pushState({}, document.title, window.location.pathname + '?stage=' + gstage + '&dir=' + gdir);
  paint(gdir,gstage);

  $('#newmod').on('submit',(e) => {
    $.ajax({
      type: "POST",
      url: "server/" + gdir,
      data: { stage: gstage, new: $("#newmod input[name=new]").val() },
      success: (r) => {
        uidash_activate_tab($('ui-tab').first());
      }
    });
    return false;
  });

  $('#newdir').on('submit',(e) => {
    $.ajax({
      type: "POST",
      url: "server/",
      data: { dir: $("#newdir input[name=newdir]").val() },
      success: (r) => {
        uidash_activate_tab($('ui-tab').first());
      }
    });
    return false;
  });
});
