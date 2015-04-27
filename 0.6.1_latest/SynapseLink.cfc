<!---
	Name         : SynapseLink.cfc
	Author       : deebo
	Created      : 4/20/2010 7:08:55 AM
	Last Updated : 4/20/2010 7:08:55 AM
	Purpose	 : I handle the info used to link classes
	History      : 8/9/2010 changed getORMClass so no longer passes back a duplicate
--->
<cfcomponent output="false">
	
	<cfproperty name="class" default="">
	<cfproperty name="foreignkeyname" default="">
	<cfproperty name="type" default="">
	<cfproperty name="isPersisted" default="">
	<cfproperty name="linktable" default="">
	<cfproperty name="linktoforeignkeyname" default="">
	
	<cffunction name="init" returntype="Any" access="public" output="false">
		<cfargument name="class" type="Any" required="true" hint="I am the sibling object">
		<cfargument name="foreignkeyname" type="String" required="true" hint="I am foreign key column name of the owning object">
		<cfargument name="type" type="String" required="true" hint="I am an indicator of the type of link ie. one-to-many(parent-child) or many-to-many(sibling)">
		<cfargument name="linktable" type="String" required="false" hint="I am the name of the linking table">
		<cfargument name="linktoforeignkeyname" type="String" required="false" hint="I am the foreign key name in the other table being linked to">
		
		<cfset VARIABLES.class = ARGUMENTS.class>
		<cfset VARIABLES.foreignkeyname = ARGUMENTS.foreignkeyname>
		<cfset VARIABLES.type = ARGUMENTS.type>
		
		<cfif structKeyExists(ARGUMENTS,'linktable')>
			<cfset VARIABLES.linktable = ARGUMENTS.linktable>
			<cfset VARIABLES.linktoforeignkeyname = ARGUMENTS.linktoforeignkeyname>
		</cfif>
		
		<cfset VARIABLES.isPersisted = true>
		
		<cfreturn this>
	</cffunction>
	
	<cffunction name="getORMClass" access="public" returntype="Any" output="false">
		<cfreturn (VARIABLES.class)>
	</cffunction>
	
	<cffunction name="getTable" access="public" returntype="String" output="false">
		<cfreturn VARIABLES.class.getTable()>
	</cffunction>
	
	<cffunction name="getAlias" access="public" returntype="String" output="false">
		<cfreturn VARIABLES.class.getAlias()>
	</cffunction>
	
	<cffunction name="getForeignKeyName" access="public" returntype="String" output="false">
		<cfreturn VARIABLES.foreignkeyname>
	</cffunction>
	
	<cffunction name="getType" access="public" returntype="String" output="false">
		<cfreturn VARIABLES.type>
	</cffunction>
	
	<cffunction name="getLinkTable" access="public" returntype="String" output="false">
		<cfreturn VARIABLES.linktable>
	</cffunction>
	
	<cffunction name="getLinkForeignKeyName" access="public" returntype="String" output="false">
		<cfreturn VARIABLES.linktoforeignkeyname>
	</cffunction>
</cfcomponent>