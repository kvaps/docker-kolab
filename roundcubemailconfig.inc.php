$config['kolab_http_request'] = array(
        'ssl_verify_peer'       => true,
        'ssl_verify_host'       => true,
        'ssl_cafile'            => '/etc/pki/tls/certs/ca-bundle.crt'
);

# caldav/webdav
$config['calendar_caldav_url']             = "https://%h/iRony/calendars/%u/%i";
$config['kolab_addressbook_carddav_url']   = 'https://%h/iRony/addressbooks/%u/%i';

# Force https redirect for http requests
$config['force_https'] = true;
?>
