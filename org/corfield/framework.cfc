<cfcomponent><cfscript>
/*
	Copyright (c) 2009-2010, Sean Corfield, Ryan Cogswell

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
*/

	this.name = hash( getCurrentTemplatePath() );

	function actionSpecifiesSubsystem( action ) {
		
		if ( not usingSubsystems() ) {
			return false;
		}
		return listLen( action, variables.framework.subsystemDelimiter ) gt 1 or right( action, 1 ) eq variables.framework.subsystemDelimiter;
	}

</cfscript><cfsilent>

	<!---
		buildURL() should be used from views to construct urls when using subsystems or
		in order to provide a simpler transition to using subsystems in the future
	--->
	<cffunction name="buildURL" access="public" output="false">
		<cfargument name="action" type="string" />
		<cfargument name="path" type="string" default="#variables.framework.baseURL#" />

		<cfset var initialDelim = '?' />

		<cfif arguments.path eq "useCgiScriptName">
			<cfset arguments.path = CGI.SCRIPT_NAME />
		</cfif>

		<cfif find( '?', arguments.path ) gt 0>
			<cfif right( arguments.path, 1 ) eq '?' or right( arguments.path, 1 ) eq '&'>
				<cfset initialDelim = '' />
			<cfelse>
				<cfset initialDelim = '&' />
			</cfif>
		</cfif>

		<cfreturn "#arguments.path##initialDelim##variables.framework.action#=#getFullyQualifiedAction(arguments.action)#" />

	</cffunction>

</cfsilent><cfscript>

	/*
	 * call this from your Application.cfc methods to queue up additional controller
	 * method calls at the start of the request
	 */
	function controller( action ) {
		var subsystem = getSubsystem( action );
		var section = getSection( action );
		var item = getItem( action );
		var tuple = structNew();
		
		if ( structKeyExists( request, 'controllerExecutionStarted' ) ) {
			raiseException( type="FW1.controllerExecutionStarted", message="Controller '#action#' may not be added at this point.",
				detail="The controller execution phase has already started. Controllers may not be added by other controller methods." );
		}
		
		tuple.controller = getController( section = section, subsystem = subsystem );
		tuple.key = subsystem & variables.framework.subsystemDelimiter & section;
		tuple.item = item;
		
		if ( structKeyExists( tuple, "controller" ) and isObject( tuple.controller ) ) {
			if ( not structKeyExists( request, 'controllers' ) ) {
				request.controllers = arrayNew(1);
			}
			arrayAppend( request.controllers, tuple );
		}
	}

	/*
	 * can be overridden to customize how views and layouts are found - can be
	 * used to provide skinning / common views / layouts etc
	 */
	function customizeViewOrLayoutPath( pathInfo, type, fullPath ) {
		// fullPath is: '#pathInfo.base##type#s/#pathInfo.path#.cfm'
		return fullPath;
	}

	/*
	 * return the action URL variable name - allows applications to build URLs
	 */
	function getAction() {
		return variables.framework.action;
	}

</cfscript><cfsilent>

	<!---
		returns whatever the framework has been told is a bean factory
		this will return a subsystem-specific bean factory if one
		exists for the current request's subsystem (or for the specified subsystem
		if passed in)
	--->
	<cffunction name="getBeanFactory" output="false">
		<cfargument name="subsystem" required="false" default="" />
		<cfscript>
			if ( len(subsystem) gt 0 ) {
				if ( hasSubsystemBeanFactory(subsystem) ) {
					return getSubsystemBeanFactory(subsystem);
				}
				return getDefaultBeanFactory();
			}
			if ( not usingSubsystems() ) {
				return getDefaultBeanFactory();
			}
			if ( structKeyExists( request, 'subsystem' ) and len(request.subsystem) gt 0 ) {
				return getBeanFactory(request.subsystem);
			}
			if ( len(variables.framework.defaultSubsystem) gt 0 ) {
				return getBeanFactory(variables.framework.defaultSubsystem);
			}
			return getDefaultBeanFactory();
		</cfscript>
	</cffunction>

</cfsilent><cfscript>

	/*
	 * returns the bean factory set via setBeanFactory
	 */
	function getDefaultBeanFactory() {
		return application[ variables.framework.applicationKey ].factory;
	}

	/*
	 * returns the name of the default subsystem
	 */
	function getDefaultSubsystem() {
	
		if ( not usingSubsystems() ) {
			return '';
		}

		if ( structKeyExists( request, 'subsystem' ) ) {
			return request.subsystem;
		}

		if ( variables.framework.defaultSubsystem eq "" ) {
			raiseException( type="FW1.subsystemNotSpecified", message="No subsystem specified and no default configured.",
					detail="When using subsystems, every request should specify a subsystem or variables.framework.defaultSubsystem should be configured." );
		}

		return variables.framework.defaultSubsystem;
		
	}

	/*
	 * return an action with all applicable parts (subsystem, section, and item) specified
	 * using defaults from the configuration or request where appropriate
	 */
	function getFullyQualifiedAction( action ) {

		if ( usingSubsystems() ) {
			return getSubsystem( action ) & variables.framework.subsystemDelimiter & getSectionAndItem( action );
		}

		return getSectionAndItem( action );

	}

</cfscript><cfsilent>

	<!--- return the item part of the action --->
	<cffunction name="getItem" output="false">
		<cfargument name="action" default="#request.action#" />

		<cfreturn listLast( getSectionAndItem( arguments.action ), '.' ) />

	</cffunction>

	<!--- return the section part of the action --->
	<cffunction name="getSection" output="false">
		<cfargument name="action" default="#request.action#" />

		<cfreturn listFirst( getSectionAndItem( arguments.action ), '.' ) />

	</cffunction>

</cfsilent><cfscript>

	/*
	 * return the action without the subsystem
	 */
	function getSectionAndItem( action ) { // "private"
	
		var sectionAndItem = '';
		
		if ( usingSubsystems() and actionSpecifiesSubsystem( action ) ) {
			if ( listLen( action, variables.framework.subsystemDelimiter ) gt 1 ) {
				sectionAndItem = listLast( action, variables.framework.subsystemDelimiter );
			}
		} else {
			sectionAndItem = action;
		}
		
		if ( len( sectionAndItem ) eq 0 ) {
			sectionAndItem = variables.framework.defaultSection & '.' & variables.framework.defaultItem;
		} else if ( listLen( sectionAndItem, '.' ) eq 1 ) {
			if ( left( sectionAndItem, 1 ) eq '.' ) {
				sectionAndItem = variables.framework.defaultSection & '.' & listLast( sectionAndItem, '.' );
			} else {
				sectionAndItem = listFirst( sectionAndItem, '.' ) & '.' & variables.framework.defaultItem;
			}
		} else {
			sectionAndItem = listFirst( sectionAndItem, '.' ) & '.' & listLast( sectionAndItem, '.' );
		}
		
		return sectionAndItem;
		
	}

	/*
	 * return the default service result key
	 * override this if you want the default service result to be
	 * stored under a different request context key, based on the
	 * requested action, e.g., return getSection( action );
	 */
	function getServiceKey( action ) {
		return "data";
	}

</cfscript><cfsilent>

	<!--- return the subsystem part of the action --->
	<cffunction name="getSubsystem" output="false">
		<cfargument name="action" default="#request.action#" />

		<cfif actionSpecifiesSubsystem( arguments.action ) >
			<cfreturn listFirst( arguments.action, variables.framework.subsystemDelimiter ) />
		</cfif>

		<cfreturn getDefaultSubsystem() />

	</cffunction>

</cfsilent><cfscript>

	/*
	* returns the bean factory set via setSubsystemBeanFactory
	* same effect as getBeanFactory when not using subsystems
	*/
	function getSubsystemBeanFactory( subsystem ) {
		
		setupSubsystemWrapper( subsystem );
		
		return application[ variables.framework.applicationKey ].subsystemFactories[ subsystem ];
		
	}


	/*
	 * returns true iff a call to getBeanFactory() will successfully return a bean factory
	 * previously set via setBeanFactory or setSubsystemBeanFactory
	 */
	function hasBeanFactory() {
		
		if ( hasDefaultBeanFactory() ) {
			return true;
		}
		
		if ( not usingSubsystems() ) {
			return false;
		}
		
		if ( structKeyExists( request, 'subsystem' ) ) {
			return hasSubsystemBeanFactory(request.subsystem);
		}
		
		if ( len(variables.framework.defaultSubsystem) gt 0 ) {
			return hasSubsystemBeanFactory(variables.framework.defaultSubsystem);
		}
		
		return false;
		
	}

	/*
	 * returns true iff the framework has been told about a bean factory via setBeanFactory
	 */
	function hasDefaultBeanFactory() {
		return structKeyExists( application[ variables.framework.applicationKey ], 'factory' );
	}

	/*
	 * returns true if a subsystem specific bean factory has been set
	 */
	function hasSubsystemBeanFactory( subsystem ) {
		
		ensureNewFrameworkStructsExist();
		
		return structKeyExists( application[ variables.framework.applicationKey ].subsystemFactories, subsystem );
		
	}

	/*
	 * layout() may be invoked inside layouts
	 * returns the UI generated by the named layout and body
	 */
	function layout( path, body ) {
		var layoutPath = parseViewOrLayoutPath( arguments.path, 'layout' );
		return internalView( layoutPath );
	}

	/*
	 * it is better to set up your application configuration in
	 * your setupApplication() method since that is called on a
	 * framework reload
	 * if you do override onApplicationStart(), you must call
	 * super.onApplicationStart() first
	 */
	function onApplicationStart() {
		setupFrameworkDefaults();
		setupApplicationWrapper();
	}
	
	/*
	 * can be overridden, calling super.onError(exception,event) is optional
	 * depending on what error handling behavior you want
	 * note: you need to rename / disable onError() on OpenBD since it does
	 * not seem to be passed exception or event correctly when something fails
	 * in the code...
	 */
	function onError(exception,event) {

		try {
			if ( structKeyExists( request, 'action' ) ) {
				request.failedAction = request.action;
			}
			request.action = variables.framework.error;
			request.exception = exception;
			request.event = event;
			structDelete( request, 'serviceExecutionComplete' );
			setupRequestWrapper();
			onRequest('');
		} catch (any e) {
			failure(exception,event);
		}

	}
	
	/*
	 * this can be overridden if you want to change the behavior when
	 * FW/1 cannot find a matching view
	 */
	function onMissingView( rc ) {
		// unable to find a matching view - fail with a nice exception
		viewNotFound();
		// if we got here, we would return the string to be rendered
		// but viewNotFound() throws an exception...
	}

	/*
	 * not intended to be overridden, automatically deleted for CFC requests
	 */
	function onRequest(targetPath) {

		var out = 0;
		var i = 0;
		var tuple = 0;
		var _data_fw1 = 0;
		var once = structNew();

		request.controllerExecutionStarted = true;
		if ( structKeyExists( request, 'controllers' ) ) {
			for ( i = 1; i lte arrayLen( request.controllers ); i = i + 1 ) {
				tuple = request.controllers[ i ];
				// run before once per controller:
				if ( not structKeyExists( once, tuple.key ) ) {
					once[ tuple.key ] = i;
					doController( tuple.controller, 'before' );
				}
				doController( tuple.controller, 'start' & tuple.item );
				doController( tuple.controller, tuple.item );
			}
		}
		for ( i = 1; i lte arrayLen( request.services ); i = i + 1 ) {
			tuple = request.services[i];
			if ( tuple.key is '' ) {
				// throw the result away:
				doService( tuple.service, tuple.item, tuple.args, tuple.enforceExistence );
			} else {
				_data_fw1 = doService( tuple.service, tuple.item, tuple.args, tuple.enforceExistence );
				if ( isDefined('_data_fw1') ) {
					request.context[ tuple.key ] = _data_fw1;
				}
			}
		}
		request.serviceExecutionComplete = true;
		if ( structKeyExists( request, 'controllers' ) ) {
			for ( i = arrayLen( request.controllers ); i gte 1; i = i - 1 ) {
				tuple = request.controllers[ i ];
				doController( tuple.controller, 'end' & tuple.item );
				// run after once per controller:
				if ( once[ tuple.key ] eq i ) {
					doController( tuple.controller, 'after' );
				}
			}
		}
		request.controllerExecutionComplete = true;
		
		buildViewAndLayoutQueue();
		
		if ( structKeyExists(request, 'view') ) {
			out = internalView( request.view );
		} else {
			out = onMissingView( request.context );
		}
		for ( i = 1; i lte arrayLen(request.layouts); i = i + 1 ) {
			if ( structKeyExists(request, 'layout') and not request.layout ) {
				break;
			}
			out = internalLayout( request.layouts[i], out );
		}
		writeOutput( out );
	}

	/*
	 * it is better to set up your request configuration in
	 * your setupRequest() method
	 * if you do override onRequestStart(), you must call
	 * super.onRequestStart() first
	 */
	function onRequestStart(targetPath) {

		var pathInfo = CGI.PATH_INFO;
		var sesIx = 0;

		setupFrameworkDefaults();

		if ( not isFrameworkInitialized() or isFrameworkReloadRequest() ) {
			setupApplicationWrapper();
		}

		if ( structKeyExists(variables.framework, 'base') ) {
			request.base = variables.framework.base;
			if ( right(request.base,1) is not '/' ) {
				request.base = request.base & '/';
			}
		} else {
			request.base = getDirectoryFromPath(targetPath);
		}
		request.base = replace( request.base, chr(92), '/', 'all' );
		if ( structKeyExists(variables.framework, 'cfcbase') ) {
			request.cfcbase = variables.framework.cfcbase;
		} else {
			if ( len(request.base) eq 1 ) {
				request.cfcbase = '';
			} else {
				request.cfcbase = replace( mid(request.base, 2, len(request.base)-2 ), '/', '.', 'all' );
			}
		}

		if ( not structKeyExists(request, 'context') ) {
			request.context = structNew();
		}
		restoreFlashContext();
		// SES URLs by popular request :)
		if ( len( pathInfo ) gt len( CGI.SCRIPT_NAME ) and left( pathInfo, len( CGI.SCRIPT_NAME ) ) is CGI.SCRIPT_NAME ) {
			// canonicalize for IIS:
			pathInfo = right( pathInfo, len( pathInfo ) - len( CGI.SCRIPT_NAME ) );
		} else if ( len( pathInfo ) gt 0 and pathInfo is left( CGI.SCRIPT_NAME, len( pathInfo ) ) ) {
			// pathInfo is bogus so ignore it:
			pathInfo = '';
		}
		pathInfo = listToArray( pathInfo, '/' );
		for ( sesIx = 1; sesIx lte arrayLen( pathInfo ); sesIx = sesIx + 1 ) {
			if ( sesIx eq 1 ) {
				request.context[variables.framework.action] = pathInfo[sesIx];
			} else if ( sesIx eq 2 ) {
				request.context[variables.framework.action] = pathInfo[sesIx-1] & '.' & pathInfo[sesIx];
			} else if ( sesIx mod 2 eq 1 ) {
				request.context[ pathInfo[sesIx] ] = '';
			} else {
				request.context[ pathInfo[sesIx-1] ] = pathInfo[sesIx];
			}
		}
		// certain remote calls do not have URL or form scope:
		if ( isDefined('URL') ) structAppend(request.context,URL);
		if ( isDefined('form') ) structAppend(request.context,form);

		if ( not structKeyExists(request.context, variables.framework.action) ) {
			request.context[variables.framework.action] = variables.framework.home;
		} else {
			request.context[variables.framework.action] = getFullyQualifiedAction( request.context[variables.framework.action] );
		}
		request.action = lCase(request.context[variables.framework.action]);

		setupRequestWrapper();

		// allow CFC requests through directly:
		if ( right(targetPath,4) is '.cfc' or targetPath is '/flex2gateway' ) {
			structDelete(this, 'onRequest');
			structDelete(variables, 'onRequest');
		}
	}

	/*
	 * it is better to set up your session configuration in
	 * your setupSession() method
	 * if you do override onSessionStart(), you must call
	 * super.onSessionStart() first
	 */
	function onSessionStart() {
		setupFrameworkDefaults();
		setupSession();
	}

</cfscript><cfsilent>

	<!---
		populate() may be invoked inside controllers
	--->
	<cffunction name="populate" access="public" output="false"
			hint="Used to populate beans from the request context.">
		<cfargument name="cfc" />
		<cfargument name="keys" default="" />
		<cfargument name="trustKeys" default="false" />

		<cfset var key = 0 />
		<cfset var property = 0 />
		<cfset var trimProperty = 0 />
		<cfset var args = 0 />

		<cfif arguments.keys is "">
			<cfif arguments.trustKeys>
				<!--- assume everything in the request context can be set into the CFC --->
				<cfloop item="property" collection="#request.context#">
					<cfset key = "set" & property />
					<cftry>
						<cfset args = structNew() />
						<cfset args[ property ] = request.context[ property ] />
						<cfinvoke component="#arguments.cfc#" method="#key#" argumentCollection="#args#" />
					<cfcatch type="any">
						<!--- ignore failures to set properties: caveat developer! --->
					</cfcatch>
					</cftry>
				</cfloop>
			<cfelse>
				<cfloop item="key" collection="#arguments.cfc#">
					<cfif len( key ) gt 3 and left( key, 3 ) is "set">
						<cfset property = right( key, len( key ) - 3 ) />
						<cfif structKeyExists( request.context, property )>
							<cfset args = structNew() />
							<cfset args[ property ] = request.context[ property ] />
							<cfinvoke component="#arguments.cfc#" method="#key#" argumentCollection="#args#" />
						</cfif>
					</cfif>
				</cfloop>
			</cfif>
		<cfelse>
			<cfloop index="property" list="#arguments.keys#">
				<cfset trimProperty = trim( property ) />
				<cfset key = "set" & trimProperty />
				<cfif structKeyExists( arguments.cfc, key ) or arguments.trustKeys>
					<cfif structKeyExists( request.context, trimProperty )>
						<cfset args = structNew() />
						<cfset args[ trimProperty ] = request.context[ trimProperty ] />
						<cfinvoke component="#arguments.cfc#" method="#key#" argumentCollection="#args#" />
					</cfif>
				</cfif>
			</cfloop>
		</cfif>

	</cffunction>

	<!---
		redirect() may be invoked inside controllers
	--->
	<cffunction name="redirect" access="public" output="false"
			hint="Redirect to the specified action, optionally append specified request context items - or use session.">
		<cfargument name="action" type="string" />
		<cfargument name="preserve" type="string" default="none" />
		<cfargument name="append" type="string" default="none" />
		<cfargument name="path" type="string" default="#variables.framework.baseURL#" />

		<cfset var queryString = "" />
		<cfset var key = "" />
		<cfset var preserveKey = "" />

		<cfif arguments.preserve is not "none">
			<cfset preserveKey = saveFlashContext(arguments.preserve) />
			<cfset queryString = "&#variables.framework.preserveKeyURLKey#=#preserveKey#">
		</cfif>

		<cfif arguments.append is not "none">
			<cfif arguments.append is "all">
				<cfloop item="key" collection="#request.context#">
					<cfif isSimpleValue( request.context[key] )>
						<cfset queryString = queryString & "&" & key & "=" & urlEncodedFormat( request.context[key] ) />
					</cfif>
				</cfloop>
			<cfelse>
				<cfloop index="key" list="#arguments.append#">
					<cfif structKeyExists( request.context, key ) and isSimpleValue( request.context[key] )>
						<cfset queryString = queryString & "&" & key & "=" & urlEncodedFormat( request.context[key] ) />
					</cfif>
				</cfloop>
			</cfif>
		</cfif>

		<cflocation url="#buildURL(arguments.action, arguments.path)##queryString#" addtoken="false" />

	</cffunction>

	<!--- call this from your controller to queue up additional services --->
	<cffunction name="service" output="false">
		<cfargument name="action" />
		<cfargument name="key" />
		<cfargument name="args" default="#structNew()#" />
		<cfargument name="enforceExistence" required="false" default="true" />
		<cfscript>
		var subsystem = getSubsystem( action );
		var section = getSection( action );
		var item = getItem( action );
		var tuple = structNew();

		if ( structKeyExists( request, "serviceExecutionComplete" ) ) {
			raiseException( type="FW1.serviceExecutionComplete", message="Service '#action#' may not be added at this point.",
				detail="The service execution phase is complete. Services may not be added by end*() or after() controller methods." );
		}

		tuple.service = getService(section=section, subsystem=subsystem);
		tuple.item = item;
		tuple.key = key;
		tuple.args = args;
		tuple.enforceExistence = enforceExistence;

		if ( structKeyExists( tuple, "service" ) and isObject( tuple.service ) ) {
			arrayAppend( request.services, tuple );
		} else if ( enforceExistence ) {
			raiseException( type="FW1.serviceCfcNotFound", message="Service '#action#' does not exist.",
				detail="To have the execution of this service be conditional based upon its existence, pass in a third parameter of 'false'." );
		}
		</cfscript>
	</cffunction>

</cfsilent><cfscript>

	/*
	 * call this from your setupApplication() method to tell the framework
	 * about your bean factory - only assumption is that it supports:
	 * - containsBean(name) - returns true if factory contains that named bean, else false
	 * - getBean(name) - returns the named bean
	 */
	function setBeanFactory( factory ) {

		application[ variables.framework.applicationKey ].factory = factory;

	}

	/*
	 * call this from your setupSubsystem() method to tell the framework
	 * about your subsystem-specific bean factory - only assumption is that it supports:
	 * - containsBean(name) - returns true if factory contains that named bean, else false
	 * - getBean(name) - returns the named bean
	 */
	function setSubsystemBeanFactory( subsystem, factory ) {
		
		ensureNewFrameworkStructsExist();
		application[ variables.framework.applicationKey ].subsystemFactories[ subsystem ] = factory;

	}

	/*
	 * override this to provide application-specific initialization
	 * if you want the framework to use a bean factory and autowire
	 * controllers and services, call setBeanFactory(factory) in your
	 * setupApplication() method
	 * you do not need to call super.setupApplication()
	 */
	function setupApplication() { }

	/*
	 * override this to provide request-specific initialization
	 * you do not need to call super.setupRequest()
	 */
	function setupRequest() { }
	
	/*
	 * override this to provide session-specific initialization
	 * you do not need to call super.setupSession()
	 */
	function setupSession() { }

	/*
	 * override this to provide subsystem-specific initialization
	 * if you want the framework to use a bean factory and autowire
	 * controllers and services, call
	 *   setSubsystemBeanFactory( subsystem, factory )
	 * in your setupSubsystem() method
	 * you do not need to call super.setupSubsystem( subsystem )
	 */
	function setupSubsystem( subsystem ) { }

	/*
	 * returns true if the application is configured to use subsystems
	 */
	function usingSubsystems() {
		return variables.framework.usingSubsystems;
	}
	
	/*
	 * view() may be invoked inside views and layouts
	 * returns the UI generated by the named view
	 */
	function view( path ) {
		var viewPath = parseViewOrLayoutPath( arguments.path, 'view' );
		return internalView( viewPath );
	}
	
</cfscript><cfsilent>

<!--- THE FOLLOWING METHODS SHOULD ALL BE CONSIDERED PRIVATE / UNCALLABLE --->
 
</cfsilent><cfscript>

	function buildViewAndLayoutQueue() { // "private"
		var siteWideLayoutBase = request.base & getSubsystemDirPrefix( variables.framework.siteWideLayoutSubsystem );
		var testLayout = 0;

		// view and layout setup - used to be in setupRequestWrapper():
		request.view = parseViewOrLayoutPath( request.subsystem & variables.framework.subsystemDelimiter & 
													request.section & '/' & request.item, 'view' );
		if ( not fileExists( expandPath( request.view ) ) ) {
			// ensures original view not re-invoked for onError() case:
			structDelete( request, 'view' );
		}

		request.layouts = arrayNew(1);
		// look for item-specific layout:
		testLayout = parseViewOrLayoutPath( request.subsystem & variables.framework.subsystemDelimiter & 
													request.section & '/' & request.item, 'layout' );
		if ( fileExists( expandPath( testLayout ) ) ) {
			arrayAppend( request.layouts, testLayout );
		}
		// look for section-specific layout:
		testLayout = parseViewOrLayoutPath( request.subsystem & variables.framework.subsystemDelimiter & 
													request.section, 'layout' );
		if ( fileExists( expandPath( testLayout ) ) ) {
			arrayAppend( request.layouts, testLayout );
		}
		// look for subsystem-specific layout (site-wide layout if not using subsystems):
		testLayout = parseViewOrLayoutPath( request.subsystem & variables.framework.subsystemDelimiter & 
													'default', 'layout' );
		if ( request.section is not 'default' and
				fileExists( expandPath( testLayout ) ) ) {
			arrayAppend( request.layouts, testLayout );
		}
		// look for site-wide layout (only applicable if using subsystems)
		testLayout = parseViewOrLayoutPath( variables.framework.siteWideLayoutSubsystem & variables.framework.subsystemDelimiter & 
													'default', 'layout' );
		if ( usingSubsystems() and siteWideLayoutBase is not request.subsystembase and
				fileExists( expandPath( testLayout ) ) ) {
			arrayAppend( request.layouts, testLayout );
		}
	}
	
	function ensureNewFrameworkStructsExist() { // "private"
	
		var framework = application[variables.framework.applicationKey];

		if ( not structKeyExists(framework, 'subsystemFactories') ) {
			framework.subsystemFactories = structNew();
		}

		if ( not structKeyExists(framework, 'subsystems') ) {
			framework.subsystems = structNew();
		}

	}

	function failure( exception, event ) { // "private"

		if ( structKeyExists(exception, 'rootCause') ) {
			exception = exception.rootCause;
		}
		writeOutput( '<h1>Exception in #event#</h1>' );
		if ( structKeyExists( request, 'failedAction' ) ) {
			writeOutput( '<p>The action #request.failedAction# failed.</p>' );
		}
		writeOutput( '<h2>#exception.message#</h2>' );
		writeOutput( '<p>#exception.detail# (#exception.type#)</p>' );
		dumpException(exception);

	}

	function getSubsystemDirPrefix( subsystem ) { // "private"

		if ( subsystem eq '' ) {
			return '';
		}

		return subsystem & '/';
	}

	function isFrameworkInitialized() { // "private"
		return structKeyExists( application, variables.framework.applicationKey );
	}

	function isFrameworkReloadRequest() { // "private"
		return ( isDefined('URL') and
					structKeyExists(URL, variables.framework.reload) and
					URL[variables.framework.reload] is variables.framework.password ) or
				variables.framework.reloadApplicationOnEveryRequest;
	}

	function isSubsystemInitialized( subsystem ) { // "private"
	
		ensureNewFrameworkStructsExist();

		return structKeyExists( application[ variables.framework.applicationKey ].subsystems, subsystem );

	}

	function parseViewOrLayoutPath( path, type ) { // "private"
		
		var pathInfo = StructNew();
		var subsystem = getSubsystem( arguments.path );

		// allow for :section/action to simplify logic in setupRequestWrapper():
		pathInfo.path = listLast( arguments.path, variables.framework.subsystemDelimiter );
		pathInfo.base = request.base;
		if ( usingSubsystems() ) {
			pathInfo.base = pathInfo.base & getSubsystemDirPrefix( subsystem );
		}

		return customizeViewOrLayoutPath( pathInfo, type, '#pathInfo.base##type#s/#pathInfo.path#.cfm' );

	}

	function setupApplicationWrapper() { // "private"

		var framework = structNew();

		framework.cache = structNew();

		framework.cache.lastReload = now();
		framework.cache.controllers = structNew();
		framework.cache.services = structNew();
		framework.subsystemFactories = structNew();
		framework.subsystems = structNew();

		application[variables.framework.applicationKey] = framework;
		setupApplication();

	}

	function setupFrameworkDefaults() { // "private"

		// default values for Application::variables.framework structure:
		if ( not structKeyExists(variables, 'framework') ) {
			variables.framework = structNew();
		}
		if ( not structKeyExists(variables.framework, 'action') ) {
			variables.framework.action = 'action';
		}
		if ( not structKeyExists(variables.framework, 'usingSubsystems') ) {
			variables.framework.usingSubsystems = false;
		}
		if ( not structKeyExists(variables.framework, 'defaultSubsystem') ) {
			variables.framework.defaultSubsystem = 'home';
		}
		if ( not structKeyExists(variables.framework, 'defaultSection') ) {
			variables.framework.defaultSection = 'main';
		}
		if ( not structKeyExists(variables.framework, 'defaultItem') ) {
			variables.framework.defaultItem = 'default';
		}
		if ( not structKeyExists(variables.framework, 'subsystemDelimiter') ) {
			variables.framework.subsystemDelimiter = ':';
		}
		if ( not structKeyExists(variables.framework, 'siteWideLayoutSubsystem') ) {
			variables.framework.siteWideLayoutSubsystem = 'common';
		}
		if ( not structKeyExists(variables.framework, 'home') ) {
			if (usingSubsystems()) {
				variables.framework.home = variables.framework.defaultSubsystem & variables.framework.subsystemDelimiter & variables.framework.defaultSection & '.' & variables.framework.defaultItem;
			} else {
				variables.framework.home = variables.framework.defaultSection & '.' & variables.framework.defaultItem;
			}
		}
		if ( not structKeyExists(variables.framework, 'error') ) {
			if (usingSubsystems()) {
				variables.framework.error = variables.framework.defaultSubsystem & variables.framework.subsystemDelimiter & variables.framework.defaultSection & '.error';
			} else {
				variables.framework.error = variables.framework.defaultSection & '.error';
			}
		}
		if ( not structKeyExists(variables.framework, 'reload') ) {
			variables.framework.reload = 'reload';
		}
		if ( not structKeyExists(variables.framework, 'password') ) {
			variables.framework.password = 'true';
		}
		if ( not structKeyExists(variables.framework, 'reloadApplicationOnEveryRequest') ) {
			variables.framework.reloadApplicationOnEveryRequest = false;
		}
		if ( not structKeyExists(variables.framework, 'preserveKeyURLKey') ) {
			variables.framework.preserveKeyURLKey = 'fw1pk';
		}
		if ( not structKeyExists(variables.framework, 'maxNumContextsPreserved') ) {
			variables.framework.maxNumContextsPreserved = 10;
		}
		if ( not structKeyExists(variables.framework, 'baseURL') ) {
			variables.framework.baseURL = 'useCgiScriptName';
		}
		if ( not structKeyExists(variables.framework, 'applicationKey') ) {
			variables.framework.applicationKey = 'org.corfield.framework';
		}
		variables.framework.version = '1.0.131';
	}

	function setupRequestWrapper() { // "private"

		request.subsystem = getSubsystem( request.action );
		request.subsystembase = request.base & getSubsystemDirPrefix( request.subsystem );
		request.section = getSection( request.action );
		request.item = getItem( request.action );

		setupSubsystemWrapper( request.subsystem );

		controller( request.action );

		request.services = arrayNew(1);
		service( request.action, getServiceKey( request.action ), structNew(), false );

		setupRequest();
	}

	function setupSessionWrapper() { // "private"
		setupSession();
	}

	function viewNotFound() { // "private"
		raiseException( type="FW1.viewNotFound", message="Unable to find a view for '#request.action#' action.",
				detail="Either '#request.subsystembase#views/#request.section#/#request.item#.cfm' does not exist or variables.framework.base is not set correctly." );
	}

</cfscript><cfsilent>

	<cffunction name="autowire" access="private" output="false"
			hint="Used to autowire controllers and services from a bean factory.">
		<cfargument name="cfc" />
		<cfargument name="beanFactory" />

		<cfset var key = 0 />
		<cfset var property = 0 />
		<cfset var args = 0 />

		<cfloop item="key" collection="#arguments.cfc#">
			<cfif len(key) gt 3 and left(key,3) is "set">
				<cfset property = right(key, len(key)-3) />
				<cfif arguments.beanFactory.containsBean(property)>
					<!--- args = [ getBeanFactory().getBean(property) ] does not seem to be portable --->
					<cfset args = structNew() />
					<cfset args[property] = arguments.beanFactory.getBean(property) />
					<cfinvoke component="#arguments.cfc#" method="#key#" argumentCollection="#args#" />
				</cfif>
			</cfif>
		</cfloop>

	</cffunction>

	<cffunction name="cfcFilePath" access="private" output="false" hint="Changes a dotted path to a filesystem path">
		<cfargument name="dottedPath" />

		<cfreturn '/' & replace( arguments.dottedPath, '.', '/', 'all' ) & '/' />

	</cffunction>

	<cffunction name="doController" access="private" output="false" hint="Executes a controller in context.">
		<cfargument name="cfc" />
		<cfargument name="method" />

		<cfset var meta = 0 />
		
		<cfif structKeyExists(arguments.cfc,arguments.method) or structKeyExists(arguments.cfc,"onMissingMethod")>
			<cftry>
				<cfinvoke component="#arguments.cfc#" method="#arguments.method#" rc="#request.context#" />
			<cfcatch type="any">
				<cfset meta = getMetadata( arguments.cfc ) />
				<cfif structKeyExists( meta, 'fullname' )>
					<cfset request.failedCfcName = meta.fullname />
				<cfelse>
					<cfset request.failedCfcName = meta.name />
				</cfif>
				<cfset request.failedMethod = arguments.method />
				<cfrethrow />
			</cfcatch>
			</cftry>
		</cfif>

	</cffunction>

	<cffunction name="doService" access="private" output="false" hint="Executes a controller in context.">
		<cfargument name="cfc" />
		<cfargument name="method" />
		<cfargument name="args" />
		<cfargument name="enforceExistence" />

		<cfset var _result_fw1 = 0 />

		<cfif structKeyExists( arguments.cfc, arguments.method ) or structKeyExists( arguments.cfc, "onMissingMethod" )>
			<cftry>
				<cfset structAppend( arguments.args, request.context, false ) />
				<cfinvoke component="#arguments.cfc#" method="#arguments.method#"
					argumentCollection="#arguments.args#" returnVariable="_result_fw1" />
			<cfcatch type="any">
				<cfset request.failedCfcName = getMetadata( arguments.cfc ).fullname />
				<cfset request.failedMethod = arguments.method />
				<cfrethrow />
			</cfcatch>
			</cftry>
			<cfif isDefined("_result_fw1")>
				<cfreturn _result_fw1 />
			</cfif>
		<cfelseif arguments.enforceExistence>
			<cfset raiseException( type="FW1.serviceMethodNotFound", message="Service method '#arguments.method#' does not exist in service '#getMetadata( arguments.cfc ).fullname#'.",
				detail="To have the execution of this service method be conditional based upon its existence, pass in a third parameter of 'false'." )>
		</cfif>

	</cffunction>

	<cffunction name="dumpException" access="private" hint="Convenience method to dump an exception cleanly.">
		<cfargument name="exception" />

		<cfdump var="#arguments.exception#" label="Exception"/>

	</cffunction>

	<cffunction name="getCachedComponent" access="private" output="false">
		<cfargument name="type" type="string" />
		<cfargument name="subsystem" type="string" />
		<cfargument name="section" type="string" />

		<cfset var cache = application[variables.framework.applicationKey].cache />
		<cfset var types = type & 's' />
		<cfset var cfc = 0 />
		<cfset var subsystemDir = getSubsystemDirPrefix(arguments.subsystem) />
		<cfset var subsystemDot = replace( subsystemDir, '/', '.', 'all' ) />
		<cfset var subsystemUnderscore = replace( subsystemDir, '/', '_', 'all' ) />
		<cfset var componentKey = subsystemUnderscore & section />
		<cfset var beanName = section & type />

		<cfset setupSubsystemWrapper(subsystem) />

		<cfif not structKeyExists(cache[types], componentKey)>
			<cflock name="fw1_#application.applicationName#_#variables.framework.applicationKey#_#type#_#componentKey#" type="exclusive" timeout="30">
				<cfscript>

					if ( not structKeyExists(cache[types], componentKey)) {

						if ( usingSubsystems() and hasSubsystemBeanFactory(subsystem) and getSubsystemBeanFactory(subsystem).containsBean(beanName) ) {

							cfc = getSubsystemBeanFactory(subsystem).getBean( beanName );

						} else if ( not usingSubsystems() and hasDefaultBeanFactory() and getDefaultBeanFactory().containsBean(beanName) ) {

							cfc = getDefaultBeanFactory().getBean( beanName );

						} else if ( fileExists( expandPath( cfcFilePath( request.cfcbase ) & subsystemDir & types & '/' & section & '.cfc' ) ) ) {

							if ( request.cfcbase is '' ) {
								cfc = createObject( 'component', subsystemDot & types & '.' & section );
							} else {
								cfc = createObject( 'component', request.cfcbase & '.' & subsystemDot & types & '.' & section );
							}
							if ( structKeyExists( cfc, 'init' ) ) {
								if ( type is 'controller' ) {
									cfc.init( this );
								} else {
									cfc.init();
								}
							}

							if ( hasDefaultBeanFactory() or hasSubsystemBeanFactory( subsystem ) ) {
   								autowire( cfc, getBeanFactory( subsystem ) );
							}
						}

						if ( isObject(cfc) ) {
							cache[types][componentKey] = cfc;
						}
					}

				</cfscript>
			</cflock>
		</cfif>

		<cfif structKeyExists(cache[types], componentKey)>
			<cfreturn cache[types][componentKey] />
		</cfif>
		<!--- else "return null" effectively --->
	</cffunction>

	<cffunction name="getController" access="private" output="false">
		<cfargument name="section" />
		<cfargument name="subsystem" default="#getDefaultSubsystem()#" required="false" />
		<cfscript>
		var _controller_fw1 = getCachedComponent("controller",subsystem,section);

		if ( isDefined('_controller_fw1') ) {
			return _controller_fw1;
		}
		</cfscript>
	</cffunction>

	<cffunction name="getNextPreserveKeyAndPurgeOld" access="private" output="false">
		<cfset var nextPreserveKey = "" />
		<cfset var oldKeyToPurge = "" />
		
		<cflock scope="session" type="exclusive" timeout="30">
			<cfparam name="session.__fw1NextPreserveKey" default="1" />
			<cfset nextPreserveKey = session.__fw1NextPreserveKey />
			<cfset session.__fw1NextPreserveKey = session.__fw1NextPreserveKey + 1/>
		</cflock>
		
		<cfset oldKeyToPurge = nextPreserveKey - variables.framework.maxNumContextsPreserved>
		<cfif StructKeyExists(session, getPreserveKeySessionKey(oldKeyToPurge))>
			<cfset structDelete(session, getPreserveKeySessionKey(oldKeyToPurge)) />
		</cfif>
		
		<cfreturn nextPreserveKey />
		
	</cffunction>

	<cffunction name="getPreserveKeySessionKey" access="private" output="false">
		<cfargument name="preserveKey" />

		<cfreturn "__fw1#arguments.preserveKey#" />

	</cffunction>

	<cffunction name="getService" access="private" output="false">
		<cfargument name="section" />
		<cfargument name="subsystem" default="#getDefaultSubsystem()#" required="false" />
		<cfscript>
		var _service_fw1 = getCachedComponent("service",subsystem,section);

		if ( isDefined('_service_fw1') ) {
			return _service_fw1;
		}
		</cfscript>
	</cffunction>

	<cffunction name="internalLayout" access="private" output="false" hint="Returns the UI generated by the named layout.">
		<cfargument name="layoutPath" />
		<cfargument name="body" />

		<cfset var rc = request.context />
		<cfset var response = '' />
		<cfset var local = structNew() />

		<cfif not structKeyExists( request, "controllerExecutionComplete" ) >
			<cfset raiseException( type="FW1.layoutExecutionFromController", message="Invalid to call the layout method at this point.",
				detail="The layout method should not be called prior to the completion of the controller execution phase." ) />
		</cfif>

		<cfsavecontent variable='response'><cfinclude template="#layoutPath#"/></cfsavecontent>

		<cfreturn response />
	</cffunction>

	<cffunction name="internalView" access="private" output="false" hint="Returns the UI generated by the named view.">
		<cfargument name="viewPath" />

		<cfset var rc = request.context />
		<cfset var response = '' />
		<cfset var local = structNew() />

		<cfif not structKeyExists( request, "controllerExecutionComplete" ) >
			<cfset raiseException( type="FW1.viewExecutionFromController", message="Invalid to call the view method at this point.",
				detail="The view method should not be called prior to the completion of the controller execution phase." ) />
		</cfif>

		<cfsavecontent variable='response'><cfinclude template="#viewPath#"/></cfsavecontent>

		<cfreturn response />

	</cffunction>

	<cffunction name="raiseException" access="private" output="false" hint="Throw an exception, callable from script.">
		<cfargument name="type" type="string" required="true" />
		<cfargument name="message" type="string" required="true" />
		<cfargument name="detail" type="string" default="" />

		<cfthrow type="#arguments.type#" message="#arguments.message#" detail="#arguments.detail#" />

	</cffunction>

	<cffunction name="restoreFlashContext" access="private" hint="Restore request context from session scope if present.">
		<cfset var preserveKey = "">
		<cfset var preserveKeySessionKey = "">
			
		<cfif not isDefined('URL') or not structKeyExists( URL, variables.framework.preserveKeyURLKey )>
			<cfreturn>
		</cfif>
		<cfset preserveKey = URL[variables.framework.preserveKeyURLKey]>
		<cfset preserveKeySessionKey = getPreserveKeySessionKey(preserveKey)>
		<cftry>
			<cfif structKeyExists(session,preserveKeySessionKey)>
				<cfset structAppend(request.context,session[preserveKeySessionKey]) />
			</cfif>
		<cfcatch type="any">
			<!--- session scope not enabled, do nothing --->
		</cfcatch>
		</cftry>

	</cffunction>

	<cffunction name="saveFlashContext" returntype="string" access="private" hint="Save request context to session scope if present.">
		<cfargument name="keys" type="string" />
		
		<cfset var currPreserveKey = getNextPreserveKeyAndPurgeOld() />
		<cfset var preserveKeySessionKey = getPreserveKeySessionKey(currPreserveKey) />
		<cfset var key = "" />

		<cftry>
			<cfparam name="session.#preserveKeySessionKey#" default="#structNew()#" />
			<cfif arguments.keys is "all">
				<cfset structAppend(session[preserveKeySessionKey],request.context) />
			<cfelse>
				<cfloop index="key" list="#arguments.keys#">
					<cfif structKeyExists(request.context,key)>
						<cfset session[preserveKeySessionKey][key] = request.context[key] />
					</cfif>
				</cfloop>
			</cfif>
		<cfcatch type="any">
			<!--- session scope not enabled, do nothing --->
		</cfcatch>
		</cftry>

		<cfreturn currPreserveKey />

	</cffunction>

	<cffunction name="setupSubsystemWrapper" access="private" output="false">
		<cfargument name="subsystem" required="true" />

		<cfif not usingSubsystems()>
			<cfreturn>
		</cfif>

		<cflock name="fw1_#application.applicationName#_#variables.framework.applicationKey#_subsysteminit_#arguments.subsystem#" type="exclusive" timeout="30">
			<cfscript>
				if ( not isSubsystemInitialized(subsystem) ) {
					application[variables.framework.applicationKey].subsystems[subsystem] = Now();
					setupSubsystem(subsystem=subsystem);
				}
			</cfscript>
		</cflock>

	</cffunction>

</cfsilent></cfcomponent>