package AntDen::Util::DB;
use strict;
use warnings;
use Carp;
use DBI;

our %MC = 
(
    'TEXT NOT NULL PRIMARY KEY' => 'VARCHAR(2000) primary key',
    'INTEGER PRIMARY KEY AUTOINCREMENT' => 'int(32) unsigned not null primary key auto_increment',
    'TEXT NOT NULL' => 'varchar(2000) NOT NULL',
    'INTEGER NOT NULL' => 'int(32) NOT NULL',
);

sub new
{
    my ( $class, $db, $autoCommit ) = splice @_, 0, 3;

    my $isMysql = ref $db eq 'HASH' ? 1 : 0;
    #TODO
    system "echo 'PRAGMA journal_mode=WAL;'|sqlite3 '$db'" if ! $isMysql && ! -f "$db-wal";

    $autoCommit ||= 0;

    if( $isMysql )
    {
        map{ die "db.$_ undef" unless $db->{$_} }qw( database user pass );
        $db = DBI->connect
        ( 
            "DBI:mysql:$db->{database}", $db->{user}, $db->{pass},
            { RaiseError => 1, PrintWarn => 0, PrintError => 0, AutoCommit => $autoCommit }
        );
    }
    else
    {
        $db = DBI->connect
        ( 
            "DBI:SQLite:dbname=$db", '', '',
            { RaiseError => 1, PrintWarn => 0, PrintError => 0, AutoCommit => $autoCommit }
        );
    }

    unless( $isMysql )
    {
        $autoCommit
          ? $db->do("PRAGMA journal_mode=WAL;")
          : $db->do("COMMIT;PRAGMA journal_mode=WAL;BEGIN");
    }

    my $self = bless { db => $db, autoCommit => $autoCommit, isMysql => $isMysql }, ref $class || $class;

    my %define = $self->define;
    map { $self->create( $_ ) } keys %define;
    $self->_stmt();

    return $self;
}

=head1 METHODS

=head3 column()

Returns table columns.

=cut
sub column
{
    my ( $self, $table ) = splice @_;
    return $self->{column}{$table};
}

=head3 create( $table )

Create $table.

=cut
sub create
{
    my ( $self, $table ) = splice @_;
    my %exist = $self->exist();

    my %define = $self->define;
    my @define = @{$define{$table}};
    my %column = @{$define{$table}};
    my @column = map { $define[ $_ << 1 ] } 0 .. @define / 2 - 1;

    $self->{column}{$table} = \@column;
    my $db = $self->{db};
    my $neat = $self->{isMysql} ? "`$table`" : DBI::neat( $table );

    unless ( $exist{$table} )
    {
        $db->do
        (
            sprintf "CREATE TABLE $neat ( %s )",
            join ', ', map { $self->{isMysql} ? "`$_` $MC{$column{$_}}" : "`$_` $column{$_}" } @column
        );
        $self->commit();
    }

    return $self;
}

sub _stmt
{
    my $self = shift;
    my $db = $self->{db};
    my %stmt = $self->stmt();
    map{
        print "load _stmt $_\n";
        $self->{stmt}{$_} = $db->prepare( $stmt{$_} );
    }keys %stmt;
    return $self;
}

sub AUTOLOAD
{
    my $self = shift;
    return unless our $AUTOLOAD =~ /::(\w+)$/;
    my $name = $1;
    $name .= shift( @_ ) if $name =~ /_$/;
    die "sql $name undef" unless my $stmt = $self->{stmt}{$name};

    my $st = $self->execute( $stmt, @_ );
    return unless $name =~ /^select/;

    my @re = @{ $st->fetchall_arrayref };
    $self->commit();
    return @re;
}

sub DESTROY
{
   my $self = shift;
   %$self = ();
}

sub exist
{
    my $self = shift;
    my $exist = $self->{db}->table_info( undef, undef, undef, 'TABLE' )
        ->fetchall_hashref( 'TABLE_NAME' );
    return %$exist; 
}

sub do
{
    my $self = shift;
    $self->execute( $self->{db}->prepare( @_ ) );
}

sub execute
{
    my ( $self, $stmt ) = splice @_, 0, 2;
    while ( $stmt )
    {
        eval { $stmt->execute( @_ ) };
        last unless $@;
        #TODO
        confess $@ if $@ !~ /locked/;
        sleep 1;
    }
    return $stmt;
}

sub commit
{
    my $this = shift;
    $this->{db}->commit() unless $this->{autoCommit};
}

sub rollback
{
    my $this = shift;
    $this->{db}->rollback() unless $this->{autoCommit};
}

1;
