#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;

BEGIN { unshift(@INC, './modules') }
BEGIN {
    use Test::Most tests => 7;
    use_ok('UpdatePipeline::Validate');
    use DateTime;
    use DateTime::Format::MySQL;
    use UpdatePipeline::VRTrack::LaneMetaData;
    use UpdatePipeline::Validate;
    use VRTrack::VRTrack;
    use UpdatePipeline::VRTrack::Project;
    use UpdatePipeline::VRTrack::Sample;
    use UpdatePipeline::VRTrack::Library;
    use UpdatePipeline::VRTrack::Lane;
    use UpdatePipeline::VRTrack::File;
    use UpdatePipeline::VRTrack::LaneMetaData;
    use UpdatePipeline::VRTrack::Study;
    use UpdatePipeline::Exceptions;
}

#create a vrtrack object
my $vrtrack = VRTrack::VRTrack->new({database => "vrtrack_test",host => "localhost",port => 3306,user => "root",password => undef});

#make sure that there is no leftover test data in the test database
delete_test_data($vrtrack);

VRTrack::Species->create($vrtrack, 'SomeBacteria' );
my $vproject = UpdatePipeline::VRTrack::Project->new(name => 'My project', external_id => 1234, _vrtrack => $vrtrack)->vr_project();
my $vstudy = UpdatePipeline::VRTrack::Study->new(accession => 'EFG456',_vr_project => $vproject)->vr_study();
$vproject->update;
my $vr_sample = UpdatePipeline::VRTrack::Sample->new(name => 'My name',common_name => 'SomeBacteria',accession => "ABC123", _vrtrack => $vrtrack,_vr_project => $vproject)->vr_sample();
my $vr_library = UpdatePipeline::VRTrack::Library->new(name => 'My library name', external_id  => 123,fragment_size_from => 123,fragment_size_to => 999, _vrtrack => $vrtrack,_vr_sample  => $vr_sample)->vr_library();
my $vr_lane = UpdatePipeline::VRTrack::Lane->new(name  => '1234_5#6', total_reads => 100000 ,_vrtrack => $vrtrack,_vr_library => $vr_library)->vr_lane();
my $vr_file = UpdatePipeline::VRTrack::File->new(name => 'myfile.bam',md5 => 'abc1231343432432432',_vrtrack => $vrtrack,_vr_lane => $vr_lane)->vr_file();
my $lane_metadata = UpdatePipeline::VRTrack::LaneMetaData->new(name => '1234_5#6',_vrtrack => $vrtrack)->lane_attributes;

#############################################
#Core tests for UpdatePipeline::Validate.pm 
#############################################
my @studies = ('EFG456');
my $validator = UpdatePipeline::Validate->new(study_names => \@studies, _vrtrack => $vrtrack);
isa_ok( $validator, 'UpdatePipeline::Validate' );
can_ok($validator, '_new_lane_changed_too_recently_to_compare');

#testing the method: '_new_lane_changed_too_recently_to_compare'


#last change date new lane >=48
$lane_metadata->{'hours_since_lane_changed'} = 120;
ok( $validator->_new_lane_changed_too_recently_to_compare( {lane_metadata => $lane_metadata, hour_threshold => 48} ) == 0, 
    'handling of new lane with lane_changed >= 48h from now'
  ); 

#last change date new lane < 48hours
$lane_metadata->{'hours_since_lane_changed'} = 17;
ok( $validator->_new_lane_changed_too_recently_to_compare( {lane_metadata => $lane_metadata, hour_threshold => 48} ) == 1, 
    'Handling of new lane with lane_changed < 48h from now'
  ); 

#a lane with processed flag not 0
$lane_metadata->{'lane_processed'} = 1; 
$lane_metadata->{'hours_since_lane_changed'} = 17;
ok( $validator->_new_lane_changed_too_recently_to_compare( {lane_metadata => $lane_metadata, hour_threshold => 48} ) == 0, 
    'A processed lane should return 0 no matter what the lane_changed value is'
  ); 

#last change date has a negative value
$lane_metadata->{'lane_processed'} = 0; 
$lane_metadata->{'hours_since_lane_changed'} = -5;
eval {
    $validator->_new_lane_changed_too_recently_to_compare( {lane_metadata => $lane_metadata, hour_threshold => 48} );
}; 
if (my $e = Exception::Class->caught('UpdatePipeline::Exceptions::InvalidTimeDiff')) {
    pass('Caught the correct exception class following a negative timediff');
} else {
    fail('Caught the correct exception class following a negative timediff');
}


delete_test_data($vrtrack);
sub delete_test_data
{
  my $vrtrack = shift;
  $vrtrack->{_dbh}->do('delete from project where name="My project"');
  $vrtrack->{_dbh}->do('delete from sample where name in ("My name")');
  $vrtrack->{_dbh}->do('delete from individual where name in ("My name")');
  $vrtrack->{_dbh}->do('delete from species where name="SomeBacteria"');
  $vrtrack->{_dbh}->do('delete from library where name in ("My library name")');
  $vrtrack->{_dbh}->do('delete from seq_centre where name in ("SC")');
  $vrtrack->{_dbh}->do('delete from seq_tech where name in ("SLX")');
  $vrtrack->{_dbh}->do('delete from lane where name in ("1234_5#6","9876_5#4")');
  $vrtrack->{_dbh}->do('delete from file where name in ("myfile.bam","myfile2.bam")');
  $vrtrack->{_dbh}->do('delete from study where acc in ("EFG456")');
}
