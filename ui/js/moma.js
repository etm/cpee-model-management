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

function moma_init() {
  var es = new EventSource('server/');
  es.onopen = function() {
    console.log('design open');
  };
  es.onmessage = function(e) {
    paint(gdir,gstage);
  };
  es.onerror = function() {
    console.log('design error');
    // design_init();
  };
}

function paint(pdir,gstage) {
  gdir = (pdir + '/').replaceAll(/\/+/g,'/');

  $('#models tbody').empty();
  $('div.breadcrumb .added').remove();

  history.pushState({}, document.title, window.location.pathname + '?stage=' + gstage + '&dir=' + gdir);
  $('div.breadcrumb span.crumb').attr('onclick','paint("","' + gstage + '")');

  let adddir = '';
  let node;
  gdir.split('/').filter((ele) => ele != '').forEach((ele,i) => {
    adddir += ele + '/';
    node = $('div.breadcrumb').append('<span class="separator added">/</span><span class="crumb added" onclick="paint(\'' + adddir + '\',\'' + gstage + '\')">' + ele.replace('.dir','') + '</span>');
  });

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
          $('[data-class=name] a',clone).attr('href','javascript:paint("' + gdir + '/' + data['name'] + '","' + gstage + '")');
        } else {
          var clone = document.importNode(document.querySelector('#model').content,true);
          $('[data-class=name] a',clone).text(data['name']);
          $('[data-class=name]',clone).attr('data-full-name',data['name']);
          $('[data-class=name] a',clone).attr('href','server/' + gdir + data['name'] + '/open?stage=' + gstage);
          $('[data-class=force] a',clone).attr('href','server/' + gdir + data['name'] + '/open-new?stage=' + gstage);
          $('[data-class=raw] a',clone).attr('href','server/' + gdir + data['name']);

          $('[data-class=guarded] abbr',clone).attr('title',data['guarded'] || '');
          $('[data-class=guarded] abbr',clone).text((data['guarded'] || '').match(/none/i) ? '' : (data['guarded'] || '').charAt(0).toUpperCase());
          $('[data-class=resource]',clone).text(data['guarded_id'] || '');

          if (data['guarded']) {
            $('[data-class=guarded] abbr',clone).attr('title',data['guarded']);
            $('[data-class=guarded] abbr',clone).text(data['guarded'].match(/none/i) ? '' : data['guarded'].charAt(0).toUpperCase());
            $('[data-class=resource]',clone).text(data['guarded_what']);
          }
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
  gdir = urlParams.get('dir') ? (urlParams.get('dir') + '/').replaceAll(/\/+/g,'/') : '';

  moma_init();

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

  $('#models').on('click','[data-class=folder], [data-class=model]',(e) => {
    $(e.currentTarget).toggleClass('selected');
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
      url: "server/" + gdir,
      data: { dir: $("#newdir input[name=newdir]").val() },
      success: (r) => {
        uidash_activate_tab($('ui-tab').first());
      }
    });
    return false;
  });
});
