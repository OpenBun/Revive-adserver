#!/usr/bin/env php
<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "CLI only\n");
    exit(1);
}

error_reporting(E_ALL & ~(E_NOTICE | E_WARNING | E_DEPRECATED));

// Required so installer forms skip CSRF tokens (same as www/admin/install.php)
define('phpAds_installing', true);

require_once __DIR__ . '/../lib/vendor/autoload.php';

use RV\Command\Installer\InstallCommand;
use Symfony\Component\Console\Application;

$application = new Application('revive-docker-install', '1.0');
$application->add(new InstallCommand());
$application->setCatchExceptions(false);
exit($application->run());
