<?php
// Moodle configuration. Every environment-specific value comes from env vars
// set in k8s/moodle/moodle.yaml, so one image works in any cluster.
// No secrets are baked into the image.

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'mysqli';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('MOODLE_DB_HOST');
$CFG->dbname    = getenv('MOODLE_DB_NAME');
$CFG->dbuser    = getenv('MOODLE_DB_USER');
$CFG->dbpass    = getenv('MOODLE_DB_PASSWORD');
$CFG->prefix    = 'mdl_';
$CFG->dboptions = [
    'dbpersist'   => 0,
    'dbport'      => 3306,
    'dbcollation' => 'utf8mb4_unicode_ci',
];

$CFG->wwwroot  = getenv('MOODLE_WWWROOT');
$CFG->dataroot = '/var/www/moodledata';
$CFG->admin    = 'admin';
$CFG->directorypermissions = 02777;

// TLS is terminated at the Traefik Ingress. Pods only see plain HTTP.
$CFG->sslproxy = true;

// Point CodeRunner at the in-cluster Jobe service instead of the public
// Canterbury demo server. The setting is forced here, so it cannot be changed
// from the admin UI.
$CFG->forced_plugin_settings = [
    'qtype_coderunner' => [
        'jobe_host'   => getenv('JOBE_HOST'),
        'jobe_apikey' => '',
    ],
];

// SSRF protection. Moodle's default blocklist covers all of 10.0.0.0/8,
// which would also block the Jobe ClusterIP (k3s service CIDR 10.43.0.0/16).
// Block everything private EXCEPT the service CIDR: the VPC and nodes,
// the pod network, and the EC2 metadata endpoint all stay blocked.
$CFG->curlsecurityblockedhosts = implode("\n", [
    '127.0.0.0/8',
    '0.0.0.0',
    'localhost',
    '::1',
    '169.254.0.0/16',
    '10.0.0.0/11',      // 10.0.0.0 - 10.31.255.255 (includes the 10.20.0.0/16 VPC)
    '10.32.0.0/13',     // 10.32.0.0 - 10.39.255.255
    '10.40.0.0/15',     // 10.40.0.0 - 10.41.255.255
    '10.42.0.0/16',     // k3s pod CIDR
    '10.44.0.0/14',     // 10.44.0.0 - 10.47.255.255
    '10.48.0.0/12',     // 10.48.0.0 - 10.63.255.255
    '10.64.0.0/10',     // 10.64.0.0 - 10.127.255.255
    '10.128.0.0/9',     // 10.128.0.0 - 10.255.255.255
    '172.16.0.0/12',
    '192.168.0.0/16',
]);

require_once(__DIR__ . '/lib/setup.php');
// There is no php closing tag in this file. This is intentional.
