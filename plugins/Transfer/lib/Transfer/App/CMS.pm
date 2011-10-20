package Transfer::App::CMS;

use strict;
use warnings;
use Transfer::Util qw( is_user_can );
use MT::Util qw( offset_time_list );

sub _convert_template_global {
    my $app = MT->instance;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_templates' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    require MT::Template;
    my @templates;
    my @tmpl_ids = $app->param('id');
    if (@tmpl_ids) {
        foreach my $tmpl_id (@tmpl_ids) {
            my $tmpl = MT::Template->load($tmpl_id);
            next unless (($tmpl->type eq 'custom') || ($tmpl->type eq 'widget'));
            $tmpl->blog_id(0);
            $tmpl->save;
        }
    }
    my $return_args = $app->param('return_args');
    $return_args =~ s!&blog_id\=[0-9]+!!;
    $app->redirect($app->uri . '?' . $return_args);
}

sub _convert_template_blog {
    my $app = MT->instance;
    my $blog_id = $app->param('itemset_action_input');
    $app->errtrans( "You must specify a blog_id to convert the template to a blog template")
        if !$blog_id;
    return MT->translate( 'Invalid request.' ) unless ($blog_id =~ /^\d+$/);
    my $blog = MT::Blog->load($blog_id);
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_templates' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    require MT::Template;
    my @templates;
    my @tmpl_ids = $app->param('id');
    if (@tmpl_ids) {
        foreach my $tmpl_id (@tmpl_ids) {
            my $tmpl = MT::Template->load($tmpl_id);
            next unless (($tmpl->type eq 'custom') || ($tmpl->type eq 'widget'));
            $tmpl->blog_id($blog_id);
            $tmpl->save;
        }
    }
    my $return_args = $app->param('return_args');
    if ($return_args =~ /blog_id\=0/) {
        $return_args =~ s!&blog_id\=0!!;
    }
    $return_args .= "&blog_id=$blog_id";
    $app->redirect($app->uri . '?' . $return_args);
}

sub _convert_template_asset {
    my $app = MT->instance;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    my $user = $app->user;
    unless ( ( is_user_can( $blog, $user, 'edit_assets' ) )
          && ( is_user_can( $blog, $user, 'edit_templates' ) ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $converted = 0;
    (my $site_path = $blog->site_path) =~ s!\\!/!g;
    require MT::Asset;
    require MT::Template;
    require MT::FileMgr;
    my @templates;
    my @tmpl_ids = $app->param('id');
    if (@tmpl_ids) {
        foreach my $tmpl_id (@tmpl_ids) {
            my $tmpl = MT::Template->load($tmpl_id);
            next unless ($tmpl->type eq 'index');
            next unless ($tmpl->outfile =~ m/\.html?$|\.mtml$|\.tmpl$|\.php$|\.jsp$|\.asp$|\.css$|\.js$/i);
            my $file = File::Spec->catfile($site_path , $tmpl->outfile);
            my $fmgr = MT::FileMgr->new( 'Local' )
              or die MT::FileMgr->errstr;
            next unless ( $fmgr->exists( $file ) );
            #FIX AND Rebuild File.
            my $basename = File::Basename::basename($file);
            my $asset_pkg = MT::Asset->handler_for_file($basename);
            my $ext = ( File::Basename::fileparse( $file, qr/[A-Za-z0-9]+$/ ) )[2];
            (my $filepath = $file) =~ s!\\!/!g;
            require LWP::MediaTypes;
            my $mimetype = LWP::MediaTypes::guess_media_type($filepath);
            my $obj = $asset_pkg->load({
                'file_path' => $filepath,
                'blog_id' => $blog->id,
            }) || $asset_pkg->new;
            my $is_new = not $obj->id;
            $filepath =~ s!$site_path!%r!;
            $obj->label($tmpl->name) if $is_new;
            $obj->file_path($filepath);
            $obj->url($filepath);
            $obj->blog_id($blog->id);
            $obj->file_name($basename);
            $obj->file_ext($ext);
            $is_new ? $obj->created_by( $app->user->id ) : $obj->modified_by( $app->user->id );
            $obj->mime_type($mimetype) if $mimetype;
            $obj->save();

            $converted = 1;
            $tmpl->remove;
        }
    }
    my $redirect_url = $converted
                     ? $app->base . $app->uri( mode => 'list',
                                               args => {
                                                   _type => 'asset',
                                                   blog_id => $blog->id,
                                               } )
                     : $app->base . $app->uri( mode => 'list_template',
                                               args => {
                                                   blog_id => $blog->id,
                                                   converted => 1,
                                               } );
    $app->redirect( $redirect_url );
}

sub _convert_entry_page {
    my $app = MT->instance;
    my $class = $app->param( '_type' );
    return MT->translate( 'Invalid request.' )
      unless (($class eq 'entry') || ($class eq 'page'));
    my $blog = $app->blog
      or return MT->translate( 'Invalid request.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_all_posts' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $blog_id = $blog->id;
    my $to_type = ($app->param('_type') eq 'page') ? 'entry' : 'page';
    return MT->translate( 'cannot make entry on website.' )
      if ((! $blog->parent_id)&&($to_type eq 'entry'));
    my @obj_ids = $app->param('id');
    my @objects;
    my $filter_val;
    if (@obj_ids) {
        foreach my $obj_id (@obj_ids) {
            my $object = MT->model($class)->load($obj_id);
            $object->class($to_type);
            $object->save;
            map {
                $_->remove;
            } MT::Placement->load({ entry_id => $obj_id });
            $filter_val .= "&filter_val=$obj_id";
        }
    } else {
        return;
    }
    $app->redirect( $app->uri
      . "?__mode=list&&_type=$to_type&saved=1"
      . "&return_args=__mode%3Dlist&_type%3D$to_type&amp;blog_id%3D$blog_id&blog_id=$blog_id$filter_val");
}

sub _copy_entries {
    my $app = shift;
    my $class = $app->param( '_type' );
    return MT->translate( 'Invalid request.' )
      unless (($class eq 'entry') || ($class eq 'page'));
    my $blog = $app->blog
      or return MT->translate( 'Invalid request.' );
    my $input = $app->param('itemset_action_input') || '';
    return MT->translate( 'Invalid request.' ) unless ($input =~ /^\d+$/);
    my $target_blog = ($input)
                    ? MT::Blog->load( $input )
                    : $app->blog;
    return MT->translate( 'Target required.' ) unless $target_blog;
    return MT->translate( 'cannot make entry on website.' ) if ((! $target_blog->parent_id)&&($class eq 'entry'));
    my $user = $app->user;
    unless ( (
               ( is_user_can( $blog, $user, 'edit_all_posts' ) )
               && ( is_user_can( $target_blog, $user, 'create_post' ) )
               && ( $class eq 'entry' )
              )
          || (
               ( is_user_can( $blog, $user, 'manage_pages' ) )
               && ( is_user_can( $target_blog, $user, 'manage_pages' ) )
               && ( $class eq 'page' )
              ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $plugin = MT->component( 'Transfer' );
    my @tl = &offset_time_list( time, $target_blog );
    my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $tl[ 5 ] + 1900, $tl[ 4 ] + 1, @tl[ 3, 2, 1, 0 ];
    my @entry_ids = $app->param( 'id' );
    for my $entry_id ( @entry_ids ) {
        my $entry = MT->model( $class )->load( { id => $entry_id } );
        if ( $entry ) {
            my @tags = $entry->get_tags;
            my $clone = $entry->clone;
            $clone->title( $plugin->translate('Copy of [_1]', $entry->title) )
              if ($entry->blog_id == $target_blog->id);
            $clone->status( MT::Entry::HOLD() );
            $clone->basename( undef );
            $clone->id( undef );
            $clone->blog_id( $target_blog->id );
            $clone->authored_on( $ts );
            $clone->created_on( $ts );
            $clone->set_tags (@tags);
            $clone->save
              or die $clone->errstr;
            if ($entry->blog_id == $target_blog->id) {
                my @placement = MT::Placement->load ({ entry_id => $entry->id });
                foreach my $placement (@placement) {
                    my $placement_clone = $placement->clone();
                    $placement_clone->id( undef );
                    $placement_clone->entry_id( $clone->id );
                    $placement_clone->save
                      or die $placement_clone->errstr;
                }
            }
            else {
                map {
                    $_->remove;
                } MT::Placement->load ({ entry_id => $entry->id });
            }
        }
    }
    my $redirect_url = $app->base
                     . $app->uri( mode => 'list',
                                  args => {
                                      _type => $class,
                                      blog_id => $target_blog->id,
                                      saved => 1,
                                  }
                       );
    $app->redirect( $redirect_url );
}

sub _move_entries {
    my $app = shift;
    my $class = $app->param( '_type' );
    return MT->translate( 'Invalid request.' )
      unless (($class eq 'entry') || ($class eq 'page'));
    my $blog = $app->blog
      or return MT->translate( 'Invalid request.' );
    my $input = $app->param('itemset_action_input') || '';
    return MT->translate( 'Invalid request.' ) unless ($input =~ /^\d+$/);
    my $target_blog = ($input)
                    ? MT::Blog->load( $input )
                    : $app->blog;
    return MT->translate( 'Target required.' ) unless $target_blog;
    return MT->translate( 'cannot make entry on website.' ) if ((! $target_blog->parent_id)&&($class eq 'entry'));
    return MT->translate( 'Same Target.' ) if ($blog->id == $target_blog->id);
    my $user = $app->user;
    unless ( (
               ( is_user_can( $blog, $user, 'edit_all_posts' ) )
               && ( is_user_can( $target_blog, $user, 'create_post' ) )
               && ( $class eq 'entry' )
              )
          || (
               ( is_user_can( $blog, $user, 'manage_pages' ) )
               && ( is_user_can( $target_blog, $user, 'manage_pages' ) )
               && ( $class eq 'page' )
              ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $plugin = MT->component( 'Transfer' );
    my @tl = &offset_time_list( time, $blog );
    my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $tl[ 5 ] + 1900, $tl[ 4 ] + 1, @tl[ 3, 2, 1, 0 ];
    my @entry_ids = $app->param( 'id' );
    for my $entry_id ( @entry_ids ) {
        my $entry = MT->model( $class )->load( { id => $entry_id } );
        if ( $entry ) {
            map {
                $_->remove;
            } MT::Placement->load ({ entry_id => $entry->id });
            my @tags = $entry->get_tags;
            $entry->blog_id ($target_blog->id);
            $entry->set_tags (@tags);
            map {
                $_->remove;
            } MT::ObjectAsset->load ({ object_id => $entry->id });
            $entry->modified_on( $ts );
            $entry->save
              or die $entry->errstr;
        }
    }
    my $redirect_url = $app->base
                     . $app->uri( mode => 'list',
                                  args => {
                                      _type => $class,
                                      blog_id => $target_blog->id,
                                      moved => 1,
                                  }
                       );
    $app->redirect( $redirect_url );
}

sub _copy_assets {
    my $app = shift;
    my $class = $app->param( '_type' );
    return MT->translate( 'Invalid request.' )
      unless ($class eq 'asset');
    my $blog = $app->blog
      or return MT->translate( 'Invalid request.' );
    my $input = $app->param('itemset_action_input') || '';
    return MT->translate( 'Invalid request.' ) unless ($input =~ /^\d+$/);
    my $target_blog = ($input)
                    ? MT::Blog->load( $input )
                    : $app->blog;
    return MT->translate( 'Target required.' ) unless $target_blog;
    my $user = $app->user;
    unless ( is_user_can( $target_blog, $user, 'upload' )) {
        return MT->translate( 'Permission denied.' );
    }
    my $plugin = MT->component( 'Transfer' );
    my @tl = &offset_time_list( time, $target_blog );
    my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $tl[ 5 ] + 1900, $tl[ 4 ] + 1, @tl[ 3, 2, 1, 0 ];
    my @asset_ids = $app->param( 'id' );
    for my $asset_id ( @asset_ids ) {
        my $asset = MT->model( 'asset' )->load( { id => $asset_id } );
        if ( $asset ) {

# File‚à•¡»‚·‚é
#

            my @tags = $asset->get_tags;
            my $clone = $asset->clone;
            $clone->label( $plugin->translate('Copy of [_1]', $asset->label) )
              if ($asset->blog_id == $target_blog->id);
            $clone->id( undef );
            $clone->blog_id( $target_blog->id );
            $clone->created_on( $ts );
            $clone->parent( undef )
              if ($asset->blog_id != $target_blog->id);
            $clone->set_tags (@tags);
            $clone->save
              or die $clone->errstr;
        }
    }
    my $redirect_url = $app->base
                     . $app->uri( mode => 'list',
                                  args => {
                                      _type => 'asset',
                                      blog_id => $target_blog->id,
                                      saved => 1,
                                  }
                       );
    $app->redirect( $redirect_url );
}

sub _move_assets {
    my $app = shift;
    my $class = $app->param( '_type' );
    return MT->translate( 'Invalid request.' )
      unless ($class eq 'asset');
    my $blog = $app->blog
      or return MT->translate( 'Invalid request.' );
    my $input = $app->param('itemset_action_input') || '';
    return MT->translate( 'Invalid request.' ) unless ($input =~ /^\d+$/);
    my $target_blog = MT::Blog->load( $input );
    return MT->translate( 'Target required.' ) unless $target_blog;
    return MT->translate( 'Same Target.' ) if ($blog->id == $target_blog->id);
    my $user = $app->user;
    unless ( ( is_user_can( $blog, $user, 'edit_assets' ) )
          && ( is_user_can( $target_blog, $user, 'upload' ) ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $plugin = MT->component( 'Transfer' );
    my @tl = &offset_time_list( time, $blog );
    my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $tl[ 5 ] + 1900, $tl[ 4 ] + 1, @tl[ 3, 2, 1, 0 ];
    (my $site_path = $blog->site_path) =~ s!\\!/!g;
    (my $target_site_path = $target_blog->site_path) =~ s!\\!/!g;
    require File::Basename;
    my @asset_ids = $app->param( 'id' );
    for my $asset_id ( @asset_ids ) {
        my $asset = MT->model( 'asset' )->load( { id => $asset_id } )
          or next;
        if ( $asset ) {
            map {
                $_->remove;
            } MT::ObjectAsset->load ({ asset_id  => $asset->id });
            (my $file = $asset->file_path) =~ s!\\!/!g;
            $file =~ s!$site_path!%r!;
            (my $dest_file = $file) =~ s!%r!$target_site_path!;
            my $dest_path = File::Basename::dirname( $dest_file );
            next unless $asset->file_path && -e $asset->file_path;
            my $fmgr = $blog->file_mgr;
            if ( !$fmgr->exists($dest_path) ) {
                $fmgr->mkpath($dest_path)
                  or die $fmgr->errstr;
            }
            $fmgr->rename($asset->file_path, $dest_file)
              or die $fmgr->errstr;
            $asset->blog_id ($target_blog->id);
            my @tags = $asset->get_tags;
            $asset->set_tags (@tags);
            $asset->save
              or die $asset->errstr;
            $asset->modified_on( $ts );
            $asset->save
              or die $asset->errstr;
        }
    }
    my $redirect_url = $app->base
                     . $app->uri( mode => 'list',
                                  args => {
                                      _type => $class,
                                      blog_id => $target_blog->id,
                                      moved => 1,
                                  }
                       );
    $app->redirect( $redirect_url );
}

sub _convert_index {
    my $app = shift;
    my $class = $app->param( '_type' );
    return MT->translate( 'Invalid request.' )
      unless ($class eq 'asset');
    my $blog = $app->blog
      or return MT->translate( 'Invalid request.' );
    my $user = $app->user;
    unless ( ( is_user_can( $blog, $user, 'edit_assets' ) )
          && ( is_user_can( $blog, $user, 'edit_templates' ) ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $plugin = MT->component( 'Transfer' );
    my $tmpl_class = MT->model('template');
    (my $site_path = $blog->site_path) =~ s!\\!/!g;
    my $converted = 0;
    my @asset_ids = $app->param( 'id' );
    for my $asset_id ( @asset_ids ) {
        my $asset = MT->model( 'asset' )->load( { id => $asset_id } );
        if ( $asset ) {
            next unless ( $asset->file_ext =~ m/^(html?|mtml|tmpl|php|jsp|asp|css|js)$/i );
            my $content = do{
                open(my $fh, '<', $asset->file_path);
                local $/;
                <$fh>;
            };
            $content =~ s!\t!    !g;
            $content =~ s!\s+\n!\n!g;
            (my $outfile = $asset->file_path) =~ s!\\!/!g;
            $outfile =~ s!$site_path!!;
            $outfile =~ s!^/!!;
            my $tmpl = $tmpl_class->new;
            $tmpl->blog_id($blog->id);
            $tmpl->text($content);
            $tmpl->outfile($outfile);
            $tmpl->type('index');
            $tmpl->name($asset->label || $asset->file_name);
            $tmpl->identifier(MT::Util::dirify($asset->file_name) || undef);
            $tmpl->save;

            $converted = 1;
            $asset->remove;
        }
    }
    my $redirect_url = $converted
                     ? $app->base . $app->uri( mode => 'list_template',
                                               args => {
                                                   blog_id => $blog->id,
                                                   converted => 1,
                                               } )
                     : $app->base . $app->uri( mode => 'list',
                                               args => {
                                                   _type => 'asset',
                                                   blog_id => $blog->id,
                                               } );
    $app->redirect( $redirect_url );
}

sub doLog {
    my ($msg) = @_; 
    use MT::Log; 
    my $log = MT::Log->new; 
    if ( defined( $msg ) ) { 
        $log->message( $msg ); 
    }
    $log->save or die $log->errstr; 
}

1;