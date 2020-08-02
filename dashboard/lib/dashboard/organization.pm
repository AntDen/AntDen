package dashboard::organization;
use Dancer ':syntax';
use JSON;
use dashboard;
our $VERSION = '0.1';

our ( %role2id, %id2role );
BEGIN{
    my @role = ( 'void', 'guest', 'master', 'owner' );
    map{ $role2id{$role[$_]} = $_; $id2role{$_} = $role[$_]; } 0.. $#role;

};
get '/organization' => sub {
    my  $param = params();
    return unless my $username = dashboard::get_username();

    my $err;
    if( 2 eq grep{ $param->{$_} }qw( name describe ) )
    {
        #TODO
        if( $dashboard::schedulerDB->selectOrganizationByName( $param->{name} ) )
        {
            $err = 'Organization already exists, please use another name';
        }
        else
        {
            $dashboard::schedulerDB->insertOrganization( $username, @$param{qw( name describe ) } );
            $dashboard::schedulerDB->insertOrganizationauth( $param->{name}, $username, 3 );
        }
    }

    my %group = +{ owner => [], guest => [], master => [], public => [] };
    my @o = $dashboard::schedulerDB->selectOrganizationauthByUser( $username );
    #`id`,`name`,`user`,`role`
    map{
        push @{$group{ $_->[2] eq '_public_' ? 'public' : $id2role{$_->[3]}}}, $_->[1]
    }@o;

    template 'organization', +{ %group, usr => $username, err => $err };
};

get '/organization/:groupname' => sub {
    my $param = params();
    return unless my $username = dashboard::get_username();

    my $err;
    my %group = +{ owner => [], guest => [], master => [], public => [] };
    my @o = $dashboard::schedulerDB->selectOrganizationauthByUser( $username );
    #`id`,`name`,`user`,`role`
    map{
        push @{$group{ $_->[2] eq '_public_' ? 'public' : $id2role{$_->[3]}}}, $_->[1]
    }@o;

    my @members = $dashboard::schedulerDB->selectOrganizationauthByName( $param->{groupname} );
    #`id`,`name`,`user`,`role`

    my $myrole = 0;
    map{

        $myrole = $_->[3] if ( $_->[2] eq '_public_' || $_->[2] eq $username ) && $_->[3] > $myrole;
    }@members;

   return template 'msg', +{ %group, usr => $username, err => 'Permission denied' } unless $myrole;

    my @machine = $dashboard::schedulerDB->selectMachineInfoByGroup( $param->{groupname} );
    #`ip`,`hostname`,`envhard`,`envsoft`,`switchable`,`group`,`workable`,`role`,`mon`
    map{ $_->[8] = $_->[8] =~ /health=1/ ? 'health=1' : 'health=0' }@machine;

    my @datasets = $dashboard::schedulerDB->selectDatasetsByGroup( $param->{groupname} );
    #`id`,`name`,`info`,`type`

    if( 2 eq grep{ $param->{$_} }qw( user role ) )
    {
        if( $myrole <= 1 ) { $err = 'Permission denied'; }
        elsif( $param->{role} >= $myrole )
        {
            $err = 'You can only add roles with lower permissions than you';
        }
        else
        {
            $dashboard::schedulerDB->insertOrganizationauth( @$param{qw( groupname user role ) } );
            @members = $dashboard::schedulerDB->selectOrganizationauthByName( $param->{groupname} );
        }
    }

    if( $param->{deleteid} )
    {
        my $delrole = 4;
        map{ $delrole = $_->[3] if $_->[0] eq $param->{deleteid} }@members;
        if( $delrole < $myrole )
        {
            $dashboard::schedulerDB->deleteOrganizationauthById( $param->{deleteid} );
            @members = $dashboard::schedulerDB->selectOrganizationauthByName( $param->{groupname} );
        }
        else { $err = 'Permission denied'; }
    }

    map{ $_->[3] = $id2role{$_->[3]} }@members;

    my @org = $dashboard::schedulerDB->selectOrganizationByName( $param->{groupname} );
    #`id`,`name`,`describe`
    my @job = $dashboard::schedulerDB->selectJobWorkInfoByGroup( $param->{groupname} );

    template 'organization/one', +{
        %group, usr => $username, members => \@members,
        groupname => $param->{groupname},
        machine => \@machine, datasets => \@datasets,
        err => $err, myrole => $id2role{$myrole},
        job => \@job,
        describe => @org ? $org[0][2] : 'null',
    };
};

true;
