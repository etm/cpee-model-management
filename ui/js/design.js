function rename_it(name) {
  var newname;
  if (newname = prompt('New name please!')) {
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
  var def = new $.Deferred();
  def.done(function(){
    $.ajax({
      type: "GET",
      url: "server/",
      success: function(res) {
        $(res).each(function(k,data) {
          var clone = document.importNode(document.querySelector('#line').content,true);
          $('[data-class=name] a',clone).text(data['name']);
          $('[data-class=name] a',clone).attr('href','server/' + data['name']);
          $('[data-class=creator]',clone).text(data['creator']);
          $('[data-class=author]',clone).text(data['author']);
          $('[data-class=date]',clone).text(new Date(data['date']).strftime('%Y-%m-%d, %H:%M:%S'));
          $('[data-class=delete] a',clone).attr('href','javascript:delete_it("' + data['name'] +'");');
          $('[data-class=rename] a',clone).attr('href','javascript:rename_it("' + data['name'] +'");');
          $('#models').append(clone);
        });
      }
    });
  });
  if (urlParams.has('new')) {
    $.ajax({
      type: "POST",
      url: "server/",
      data: { new: urlParams.get('new') },
      success: function() { def.resolve(); },
      error: function() { def.reject(); }
    });
    history.pushState({}, document.title, window.location.pathname);
  } else {
    def.resolve();
  }
});
