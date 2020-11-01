function rename_it(name) {
  var newname;
  if (newname = prompt('New name please!',name.replace(/\.xml$/,''))) {
    $.ajax({
      type: "PUT",
      url: "server/" + name,
      data: { new: newname },
      success: function(res) {
        $.ajax({
          type: "DELETE",
          url: "server/" + name,
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
      url: "server/",
      data: { new: newname, old: name },
      success: function() { location.reload(); },
    });
  }
}
function delete_it(name) {
  if (confirm('Are you really, really, REALLY sure!')) {
    $.ajax({
      type: "DELETE",
      url: "server/" + name,
      success: function(res) {
        location.reload();
      }
    });
  }
}

$(document).ready(function() {
  const queryString = window.location.search;
  const urlParams = new URLSearchParams(queryString);
  $('input[name=stage]').val(urlParams.get('stage') || 'draft');
  $('ui-behind').text(urlParams.get('stage') || 'draft');
  $('#models').on('click','td[data-class=ops]',(e) => {
    console.log(e);
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
    $.ajax({
      type: "GET",
      url: "server/",
      data: { stage: urlParams.get('stage') || 'draft' },
      success: function(res) {
        $(res).each(function(k,data) {
          var clone = document.importNode(document.querySelector('#model').content,true);
          $('[data-class=name] a',clone).text(data['name']);
          $('[data-class=name] a',clone).attr('href','server/' + data['name']);
          $('[data-class=creator]',clone).text(data['creator']);
          $('[data-class=author]',clone).text(data['author']);
          $('[data-class=date]',clone).text(new Date(data['date']).strftime('%Y-%m-%d, %H:%M:%S'));
          $('[data-class=delete] a',clone).attr('href','javascript:delete_it("' + data['name'] +'");');
          $('[data-class=rename] a',clone).attr('href','javascript:rename_it("' + data['name'] +'");');
          $('[data-class=duplicate] a',clone).attr('href','javascript:duplicate_it("' + data['name'] +'");');
          $('#models tbody').append(clone);
        });
      }
    });
  });
  if (urlParams.has('new')) {
    $.ajax({
      type: "POST",
      url: "server/",
      data: { stage: urlParams.get('stage'), new: urlParams.get('new') },
      success: function() { def.resolve(); },
      error: function() { def.reject(); }
    });
    history.pushState({}, document.title, window.location.pathname + '?stage=' + urlParams.get('stage') || 'draft');
  } else {
    def.resolve();
  }
});
