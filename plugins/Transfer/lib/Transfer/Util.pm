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
    if ($app->param('filter_key')) {
        my $type = $app->param('filter_key');
        unless ($blog_id && $type && (($type eq 'module_templates') || ($type eq 'widget_templates'))) {
            return 0;
        }
        }
    if (($app->mode eq 'view') && (($app->{query}->param('_type') || '') eq 'template')) {
        my $id = $app->{query}->param('id')
          or return 0;
        require MT::Template;
        my $tmpl = MT::Template->load($id)
          or return 0;
        return 0
          unless (($tmpl->type eq 'custom') || ($tmpl->type eq 'widget'));
        return 0
          unless (($tmpl->blog_id == $blog_id) || $blog_id);
    }
    return 1;
}

sub is_global_module {
    my $app = MT->instance;
    my $blog_id = $app->param('blog_id') || 0;
    return 0 if $blog_id;
    if ($app->param('filter_key')) {
        my $type = $app->param('filter_key');
        return 0
          unless ($type && (($type eq 'module_templates') || ($type eq 'widget_templates')));
    }
    if (($app->mode eq 'view') && (($app->{query}->param('_type') || '') eq 'template')) {
        my $id = $app->{query}->param('id')
          or return 0;
        require MT::Template;
        my $tmpl = MT::Template->load($id)
          or return 0;
        return 0
          unless (($tmpl->type eq 'custom') || ($tmpl->type eq 'widget'));
        return 0
          unless (($tmpl->blog_id == $blog_id));
    }
    return 1;
}

sub is_blog {
    my $app = MT->instance;
    my $blog = $app->blog;
    return 0 if (!$blog );
    return 1
      if ( $blog->id && $blog->parent_id );
    return 0;
}

sub is_index_template {
    my $app = MT->instance;
    my $blog = $app->blog;
    return 0 if (!$blog );
    return 0 unless $blog->id;
    if ($app->param('filter_key')) {
        my $type = $app->param('filter_key');
        return 0
          unless ($type && ($type eq 'index_templates'));
    }
    if (($app->mode eq 'view') && (($app->{query}->param('_type') || '') eq 'template')) {
        my $id = $app->{query}->param('id')
          or return 0;
        require MT::Template;
        my $tmpl = MT::Template->load($id)
          or return 0;
        return 0
          unless ($tmpl->type eq 'index');
        return 0
          unless (($tmpl->blog_id == $blog->id));
    }
    return 1;
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
    return 0;
}

sub is_illiad {
    my $version = MT->version_id;
    return 1
      if ($version >= 5.1);
    return 0;
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