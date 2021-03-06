package MojoRPC::Server::ResponseFormatter::JSON;
use Mojo::Base 'MojoRPC::Server::ResponseFormatter';
use Scalar::Util qw(blessed);

sub render {
	my $self = shift;

	$self->controller->res->headers->content_type('application/json');

	#Try and prevent the server from locking up for bad objects that self reference
	eval {
		local $SIG{ ALRM } = sub { die "Timed out in recursive JSON call" };
		alarm ($self->controller->req->headers->header("RPC-Timeout") || 10); #We aren't a websocket/comet server so don't keep us blocked for more than 5 seconds
		$self->controller->render(json => $self->json);
		alarm 0;
	};
	if($@) {
		alarm 0;
		if($@ eq "Timed out in recursive JSON call") {
	  		#Time out
	  		$self->controller->render_text_exception($@) and return;
		}
		else {
	  		#Died for some other reason
		}
		$self->controller->render_text_exception($@);  
	}
}

sub json {
  my $self = shift;
  
  my $response_hash = {};

  #Hack for array of 1 item
  if(
    ref($self->method_return_value) eq "ARRAY" &&
    scalar(@{$self->method_return_value}) == 1
  ) {
    $self->method_return_value( $self->method_return_value->[0] );
  }

  if(blessed $self->method_return_value) {
    my $id = $self->method_return_value->can('id') ? $self->method_return_value->id() : $self->method_return_value->{id};
    $response_hash->{id} = $id if $id;
    $response_hash->{class} = ref($self->method_return_value);
    $response_hash->{data} = $self->method_return_value->TO_JSON;
  }
  else {
     $response_hash->{data} = $self->method_return_value;
  }   

  return $response_hash;	
}

1;