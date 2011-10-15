package Transfer::Util;

use strict;
use base 'Exporter';
our @EXPORT_OK = qw( is_user_can );

sub is_blog_module {
    my $app = MT->instance;
    my $blog = $app->blog;
    return 0 if (!$blog );
    my $blog_id = $blog->id;
    return 1 if $app->param('action_name');
    my $type = $app->param('filter_key');
    my $mod_or_wid;
    if ($type && ($type eq 'module_templates' || $type eq 'widget_templates')) {
        $mod_or_wid = 1;
    }
    return 1 if ($blog_id && $mod_or_wid);
}

sub is_global_module {
    my $app = MT->instance;
    my $blog_id = $app->param('blog_id') || 0;
    return 0 if $blog_id;
    #FIX condition will work execute code. but has no $app->param('filter_key')!
    return 1;
}

sub is_blog {
    my $app = MT->instance;
    my $blog = $app->blog;
    return 0 if (!$blog );
    return 1
      if ( $blog->parent_id );
}

sub is_index_template {
    my $app = MT->instance;
    my $blog = $app->blog;
    return 0 if (!$blog );
    my $blog_id = $blog->id;
    my $type = $app->param('filter_key');
    if ($type && ($type eq 'index_templates')) {
        return 1;
    }
    else {
        return 0;
    }
}

sub is_user_can {
    my ( $blog, $user, $permission ) = @_;
    $permission = 'can_' . $permission;
    my $perm = $user->is_superuser;
    unless ( $perm ) {
        if ( $blog ) {
            my $admin = 'can_administer_blog';
            $perm = $user->permissions( $blog->id )->$admin;
            $perm = $user->permissions( $blog->id )->$permission unless $perm;
        } else {
            $perm = $user->permissions()->$permission;
        }
    }
    return $perm;
}

sub is_mt5 {
    my $version = MT->version_id;
    return 1
      if (($version < 5.1)&&($version >= 5));
}

sub is_illiad {
    my $version = MT->version_id;
    return 1
      if ($version >= 5.1);
}

sub doLog {
    my ($msg) = @_; 
    return unless defined($msg);
    require MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}

1;