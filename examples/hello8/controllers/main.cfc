component accessors="true" {
	
	property framework;
	property mainService;
	
	public void function default( rc ) {
		param name="rc.name" default="anonymous";
		rc.data = variables.mainService.default( rc.name );
		rc.captured = variables.framework.view( "main/capture" );
	}
}