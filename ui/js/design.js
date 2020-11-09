var gstage;
var gdir;

function move_it(name,todir) {
  console.log(todir);
  $.ajax({
    type: "PUT",
    url: "server/" + gdir + name,
    data: { dir: todir },
    success: function(res) {
      location.reload();
    }
  });
}
function rename_it(name) {
  var newname;
  if (newname = prompt('New name please!',name.replace(/\.xml$/,''))) {
    $.ajax({
      type: "PUT",
      url: "server/" + gdir + name,
      data: { new: newname },
      success: function(res) {
        $.ajax({
          type: "DELETE",
          url: "server/" + gdir + name,
          success: function(res) {
            location.reload();
          }
        });
      }
    });
  }
}
function duplicate_it(name) {
  var newname;
  if (newname = prompt('New name please!',name.replace(/\.xml$/,''))) {
    $.ajax({
      type: "POST",
      url: "server/" + gdir,
      data: { new: newname, old: name },
      success: function() { location.reload(); },
    });
  }
}
function delete_it(name) {
  if (confirm('Are you really, really, REALLY sure!')) {
    $.ajax({
      type: "DELETE",
      url: "server/" + gdir + name,
      success: function(res) {
        location.reload();
      }
    });
  }
}

$(document).ready(function() {
  const queryString = window.location.search;
  const urlParams = new URLSearchParams(queryString);

  gstage = urlParams.get('stage') || 'draft';
  gdir = urlParams.get('dir') ? (urlParams.get('dir') + '/').replace(/\/+/,'/') : '';

  $('input[name=stage]').val(gstage);
  $('input[name=dir]').val(gdir);
  $('ui-behind').text(gstage);


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
      console.log(dragged);
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
    var name = $(e.currentTarget).parents('tr').find('td[data-class=name] a').text();
    menu['Operations'] = [
      {
        'label': 'Duplicate',
        'function_call': duplicate_it,
        'text_icon': '➕',
        'type': undefined,
        'params': [name]
      },
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
    new CustomMenu(e).contextmenu(menu);
  });
  var def = new $.Deferred();
  def.done(function(){
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
            $('[data-class=name] a',clone).attr('href',window.location.pathname + '?stage=' + gstage + '&dir=' + data['name']);
          } else {
            var clone = document.importNode(document.querySelector('#model').content,true);
            $('[data-class=name] a',clone).text(data['name']);
            $('[data-class=name] a',clone).attr('href','server/' + gdir + data['name']);
          }
          $('[data-class=creator]',clone).text(data['creator']);
          $('[data-class=author]',clone).text(data['author']);
          $('[data-class=date]',clone).text(new Date(data['date']).strftime('%Y-%m-%d, %H:%M:%S'));
          $('#models tbody').append(clone);
        });
      }
    });
  });
  history.pushState({}, document.title, window.location.pathname + '?stage=' + gstage + '&dir=' + gdir);
  if (urlParams.has('new')) {
    $.ajax({
      type: "POST",
      url: "server/" + gdir,
      data: { stage: gstage, new: urlParams.get('new') },
      success: function() { def.resolve(); },
      error: function() { def.reject(); }
    });
  } else {
    def.resolve();
  }
  if (urlParams.has('newdir')) {
    $.ajax({
      type: "POST",
      url: "server/",
      data: { dir: urlParams.get('newdir') },
      success: function() { def.resolve(); },
      error: function() { def.reject(); }
    });
  } else {
    def.resolve();
  }
});
