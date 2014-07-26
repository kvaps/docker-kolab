$config['kolab_http_request'] = array(
        'ssl_verify_peer'       => true,
        'ssl_verify_host'       => true,
        'ssl_cafile'            => '/etc/pki/tls/certs/ca-bundle.crt'
);

# caldav/webdav
$config['calendar_caldav_url']             = "https://foo.bar.tld/iRony/calendars/%u/%i";
$config['kolab_addressbook_carddav_url']   = 'https://foo.bar.tld/iRony/addressbooks/%u/%i';
?>
