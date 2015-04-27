<!---
	Name         : SynapseProperty.cfc
	Author       : deebo
	Created      : 4/20/2010 7:11:59 AM
	Last Updated : 4/20/2010 7:11:59 AM
	Purpose	 : I handle the property metadata gleaned from the database for a property
	History      : 
--->
<cfcomponent output="false">
	<cfproperty name="VARIABLES.table" default="">
	<cfproperty name="VARIABLES.name" default="">
	<cfproperty name="VARIABLES.type" default="">
	<cfproperty name="VARIABLES.size" default="">
	<cfproperty name="VARIABLES.defaultValue" default="">
	<cfproperty name="VARIABLES.isnullable" default="">
	<cfproperty name="VARIABLES.isprimarykey" default="">
	<cfproperty name="VARIABLES.isforeignkey" default="">
	<cfproperty name="VARIABLES.referencedtable" default="">
	<cfproperty name="VARIABLES.referencedkey" default="">
	<cfproperty name="VARIABLES.ignoreOnUpdate" default="false">
	
	<cffunction name="init" returntype="Any" output="false" access="public">
		<cfargument name="query" type="Any" required="true">
		<!--- <cfset VARIABLES.table = ARGUMENTS.query['TABLE_NAME'][ARGUMENTS.query.CURRENTROW]> --->
		<cfset VARIABLES.name = ARGUMENTS.query['COLUMN_NAME'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.type = ARGUMENTS.query['TYPE_NAME'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.size = ARGUMENTS.query['COLUMN_SIZE'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.defaultValue = ARGUMENTS.query['COLUMN_DEFAULT_VALUE'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.isnullable = ARGUMENTS.query['IS_NULLABLE'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.isprimarykey = ARGUMENTS.query['IS_PRIMARYKEY'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.isforeignkey = ARGUMENTS.query['IS_FOREIGNKEY'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.referencedtable = ARGUMENTS.query['REFERENCED_PRIMARYKEY_TABLE'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.referencedkey = ARGUMENTS.query['REFERENCED_PRIMARYKEY'][ARGUMENTS.query.CURRENTROW]>
		<cfset VARIABLES.ignoreOnUpdate = false>
		
		<cfreturn this>
	</cffunction>
	
	<cffunction name="getDefaultValue" returntype="Any" access="public" output="false" hint="I return the default value for this property">
		<cfset LOCAL.result = VARIABLES.defaultValue>
		<cfif NOT VARIABLES.isNullable>
			<cfswitch expression="#this.getType()#">
				<cfcase value="bit">
					<cfset LOCAL.result = mid(LOCAL.result,3,1)>
				</cfcase>
				<cfcase value="datetime">
					<cfset LOCAL.result = '#dateFormat(now(),"yyyy-mm-dd")# #timeFormat(now(),"HH:mm:ss")#'>
				</cfcase>
				<cfdefaultcase></cfdefaultcase>
			</cfswitch>
		</cfif>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="ignoreOnUpdate" access="public" returntype="Any" output="false" hint="I set/override the properties to ignore on update">
		<cfargument name="ignore" required="false" type="String" hint="I am a boolean indicating whether to ignore this property on update">
			<cfif structKeyExists(ARGUMENTS,'ignore')>
				<cfset VARIABLES.ignoreOnUpdate = ARGUMENTS.ignore>
			<cfelse>
				<cfreturn VARIABLES.ignoreOnUpdate>
			</cfif>
	</cffunction>
	
	<cffunction name="isNullable" access="public" returntype="Boolean" output="false" hint="I return whether this property isnullable">
			<cfif VARIABLES.isnullable EQ ''>
				<cfset VARIABLES.isnullable = true>
			</cfif>
			<cfreturn VARIABLES.isnullable>
	</cffunction>
	
	<cffunction name="onMissingMethod" access="public" returnType="any" output="false">
		<cfargument name="missingMethodName" type="string" required="true">
		<cfargument name="missingMethodArguments" type="struct" required="true">
		<cfset LOCAL.key = "">

		<cfif left(ARGUMENTS.missingMethodName,3) IS "get">
			<cfset LOCAL.key = right(ARGUMENTS.missingMethodName, len(ARGUMENTS.missingMethodName)-3)>
			<cfif structKeyExists(VARIABLES, LOCAL.key)>
				<cfreturn VARIABLES[LOCAL.key]>
			</cfif>
		</cfif>

		<cfif left(ARGUMENTS.missingMethodName,3) IS "set">
			<cfset LOCAL.key = right(ARGUMENTS.missingMethodName, len(ARGUMENTS.missingMethodName)-3)>
			<cfif structCount(ARGUMENTS.missingMethodArguments) EQ 1>
				<cfset VARIABLES[LOCAL.key] = ARGUMENTS.missingMethodArguments[1]>
			<cfelse>
				<cfset VARIABLES[LOCAL.key] = ARGUMENTS.missingMethodArguments[LOCAL.key]>
			</cfif>
		</cfif>

	</cffunction>
</cfcomponent>