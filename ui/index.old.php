<!--
  This file is part of centurio.work/commands.

  centurio.work/commands is free software: you can redistribute it and/or
  modify it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  centurio.work/commands is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
  more details.

  You should have received a copy of the GNU General Public License along with
  centurio.work/commands (file COPYING in the main directory).  If not, see
  <http://www.gnu.org/licenses/>.
-->

<?php
  // ini_set('display_errors', 1);
  // ini_set('display_startup_errors', 1);
  // error_reporting(E_ALL);

  function handleREST($server,$get) {
    $ret = new StdClass;
    $ret->raw = file_get_contents('php://input');
    $url = (array_key_exists('PATH_INFO',$server) ? $server['PATH_INFO'] : '/');
    $method = $server['REQUEST_METHOD'];
    parse_str($ret->raw,$contentargs);
    $arguments = array_merge($get,$contentargs);
    $accept = array_key_exists('HTTP_ACCEPT',$server) ? $server['HTTP_ACCEPT'] : '*/*';
    $ret->url = $url;
    $ret->method = $method;
    $ret->arguments = $arguments;
    $ret->accept = $accept;
    $ret->dn = array();
    foreach (explode(',',$server['DN']) as $item) {
      $it = explode('=',$item,2);
      $ret->dn[$it[0]] = $it[1];
    };
    return $ret;
  }

  $rest = handleREST($_SERVER,$_GET);

  if ($rest->method == 'PUT') {
    $xmlstr = $rest->raw;
    $xml2 = simplexml_load_string($xmlstr);

    $xml2->registerXPathNamespace('x', 'http://riddl.org/ns/common-patterns/properties/1.0');
    $info = $xml2->xpath('/testset/attributes/x:info');
    $filename = preg_replace( '/[^a-zA-Z0-9öäüÖÄÜ _-]+/', '-', $info[0]);

    $xml1 = simplexml_load_file('models/' . $filename . '.xml');

    $domReplace  = dom_import_simplexml($xml2->description->description);

    $domToChange = dom_import_simplexml($xml1->description->description);
    $nodeImport  = $domToChange->ownerDocument->importNode($domReplace, TRUE);
    $domToChange->parentNode->replaceChild($nodeImport, $domToChange);

    $domToChange = dom_import_simplexml($xml1->dslx->description);
    $nodeImport  = $domToChange->ownerDocument->importNode($domReplace, TRUE);
    $domToChange->parentNode->replaceChild($nodeImport, $domToChange);

    $xml1->asXML('models/' . $filename . '.xml');
    exit;
  }
  if ($rest->method == 'GET' && $rest->arguments['new']) {
    $filename = preg_replace( '/[^a-zA-Z0-9öäüÖÄÜ _-]+/', '-', $rest->arguments['new']);
    $fname = $filename;
    $counter = 1;
    while (file_exists('models/' . $fname . '.xml')) {
      $fname = $filename . '_' . $counter;
      $counter += 1;
    }

    $xml = simplexml_load_file('model.xml');
    $xml->registerXPathNamespace('x', 'http://riddl.org/ns/common-patterns/properties/1.0');
    $info = $xml->xpath('/x:properties/x:attributes/x:info');
    foreach($info as $ele) {
      $ele[0] = $fname;
    }
    $author = $xml->xpath('/x:properties/x:attributes/x:author');
    foreach($author as $ele) {
      $ele[0] = $rest->dn['GN'] . ' ' . $rest->dn['SN'];
    }

    $xml->asXML('models/' . $fname . '.xml');
  }

?>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <title>Design</title>

    <!-- libs, do not modify. When local than load local libs. -->
    <script type="text/javascript" src="/js_libs/jquery.min.js"></script>
    <script type="text/javascript" src="/js_libs/jquery.browser.js"></script>
    <script type="text/javascript" src="/js_libs/jquery.svg.min.js"></script>
    <script type="text/javascript" src="/js_libs/jquery.svgdom.min.js"></script>
    <script type="text/javascript" src="/js_libs/vkbeautify.js"></script>
    <script type="text/javascript" src="/js_libs/util.js"></script>
    <script type="text/javascript" src="/js_libs/printf.js"></script>
    <script type="text/javascript" src="/js_libs/strftime.min.js"></script>
    <script type="text/javascript" src="/js_libs/parsequery.js"></script>
    <script type="text/javascript" src="/js_libs/underscore.min.js"></script>
    <script type="text/javascript" src="/js_libs/jquery.caret.min.js"></script>
    <script type="text/javascript" src="/js_libs/jquery.cookie.js"></script>

    <script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/jquery.qrcode/1.0/jquery.qrcode.min.js"></script>

    <script type="text/javascript" src="/js_libs/relaxngui.js"></script>

    <script type="text/javascript" src="/js_libs/ui.js"></script>
    <script type="text/javascript" src="/js_libs/custommenu.js"></script>

    <link   rel="stylesheet"      href="/js_libs/custommenu.css" type="text/css"/>
    <link   rel="stylesheet"      href="/js_libs/ui.css" type="text/css"/>

    <link   rel="stylesheet"      href="/js_libs/relaxngui.css" type="text/css"/>

    <!-- custom stuff, play arround  -->
    <link rel="stylesheet" href="css/ui.css" type="text/css"/>
    <script>
      $(document).ready(function() {
        const queryString = window.location.search;
        const urlParams = new URLSearchParams(queryString);
        if (urlParams.has('new')) {
          history.pushState({}, document.title, '/design/');
        }
      });
    </script>
    <style>
      td {
        padding-right: 1em;
      }
    </style>
  </head>
  <body>
    <form action="" method="get">
      <input type="text" name="new"/>
      <button type="submit">New Model</button>
    </form>

    <h1>List of Models:</h1>

    <table>
    <?php
      $dir = "models/";
      if (is_dir($dir)) {
        if ($dh = opendir($dir)) {
          while (($file = readdir($dh)) !== false) {
            if (!preg_match('/^\./',$file)) {
              $xml = simplexml_load_file($dir . $file);
              $xml->registerXPathNamespace('x', 'http://riddl.org/ns/common-patterns/properties/1.0');
              echo "<tr>";
              echo "<td><a target='_blank' href='https://centurio.work/flow-test/model.html?instantiate=https://centurio.work/design/models/" . $file . "'>" . $file . "</a></td>";
              echo "<td>" . $xml->xpath('/x:properties/x:attributes/x:author')[0] . "</td>";
              echo "<td>" . date('Y-m-d, H:i:s',filemtime($dir . $file)) . "</td>";
              echo "</tr>";
            }
          }
          closedir($dh);
        }
      }
    ?>
    </table>
  </body>
</html>
