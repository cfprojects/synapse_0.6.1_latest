<cfcomponent output="false">
<!---
	Name         	: ListIterator.cfc
	Author       	: Devon Burriss
	Created      	: 4/23/2010 7:14:07 AM
	Last Updated 	: 4/23/2010 7:14:07 AM
	Purpose	 		: I iterate over an array,list,struct, or query
	History      	: 	30/7/2010 worked on correct insert when using previous
						30/7/2010 worked on making index work consistently between previous and next
					: 11/4/2011 changed 1st and last to send back empty bean if collection is empty
--->
<!--- 
===================================================================================================================
// METHOD SUMMARY
===================================================================================================================
 void	add(Object o) 
          Inserts the specified element into the list (optional operation).
 boolean	hasNext() 
          Returns true if this list iterator has more elements when traversing the list in the forward direction.
 boolean	hasPrevious() 
          Returns true if this list iterator has more elements when traversing the list in the reverse direction.
 Object	next() 
          Returns the next element in the list.
 int	nextIndex() 
          Returns the index of the element that would be returned by a subsequent call to next.
 Object	previous() 
          Returns the previous element in the list.
 int	previousIndex() 
          Returns the index of the element that would be returned by a subsequent call to previous.
 void	remove() 
          Removes from the list the last element that was returned by next or previous (optional operation).
 void	set(Object o) 
          Replaces the last element returned by next or previous with the specified element (optional operation).
===================================================================================================================
          Element(1)   Element(2)   Element(3)   ... Element(n)   
        ^            ^            ^            ^               ^
 Index: 1            2            3            4               n+1
===================================================================================================================
 
--->
<!--- PARAM --->

<!--- INITIALIZE --->
	<cffunction name="init" returntype="Any" output="false">
		<cfargument name="collection" required="true" type="Any">
		<cfargument name="class" required="true" type="Any">
		
		<cfset VARIABLES.n = 1>
		<cfset VARIABLES.collection = structNew()>
		<cfset VARIABLES.keys = arrayNew(1)>
		<cfset VARIABLES._lastAction = ''>
		<cfset VARIABLES.class = ARGUMENTS.class>
		
		<!--- init based on passed collection type --->
		<cfif structKeyExists(ARGUMENTS,'collection')>
			<cfset VARIABLES.collection = ARGUMENTS.collection>
			<!--- PERFORM COLLECTION TYPE SPECIFIC PROCESSING --->
			<cfif isQuery(ARGUMENTS.collection)>
				<!--- QUERY --->
				<cfset VARIABLES.keys = VARIABLES.collection.getColumnNames()>
			<cfelseif isArray(ARGUMENTS.collection)>
				<!--- ARRAY:none --->
				
			<cfelseif isStruct(ARGUMENTS.collection)>
				<!--- STRUCT --->
				<cfset VARIABLES.keys = structKeyArray(VARIABLES.collection)>
			<cfelseif isSimpleValue(ARGUMENTS.collection)>
				<!--- LIST: We make it an array so we don't have to worry about list type anymore --->
				<!--- <cfset VARIABLES.collection = listToArray(VARIABLES.collection)> --->
			</cfif>
		</cfif>
		<cfreturn this>
	</cffunction>
	
<!--- IMPLEMENTATION --->	
	<cffunction name="add" output="false" returntype="void" access="public" hint="Inserts the specified element into the list">
		<cfargument name="o" required="true" type="Any" hint="Add this object to the current position of the iterator">
		
		<cfset var LOCAL = structNew()>
		
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		
		<cfset LOCAL.ammend = 0>
		<cfif lastAction() EQ 'next'>
			<cfset LOCAL.ammend = -1>
		<cfelseif lastAction() EQ 'previous'>
			<cfset LOCAL.ammend = 1>
		</cfif>
		
		<!--- THROW EXCEPTION IF NEXT NOT CALLED OR PREVIOUS CALLED MORE OR EQUAL TIMES  --->
		<cfif VARIABLES.n EQ 0>
			<cfthrow message="IllegalStateException">
		</cfif>
		<!--- INSERT o INTO VARIABLES.collection AT THE CURRENT ITERATOR POSITION n --->
		<cfif isQuery(VARIABLES.collection)>
			<cfif NOT isStruct(ARGUMENTS.o)>
				<cfthrow message="IllegalArgumentException">
			</cfif>

			<!--- CREATE TEMP QUERY --->
			<cfset LOCAL.qTemp = queryNew(arrayToList(VARIABLES.keys))>
			
			<!--- loop throw collection till n and add add to temp --->
			<cfloop query="VARIABLES.collection">
				<!--- if at current iterator index, insert a o --->
				<cfif VARIABLES.collection.currentRow EQ VARIABLES.n>
					<cfset queryAddRow(LOCAL.qTemp)>
					<cfloop collection="#ARGUMENTS.o#" item="keyName">
						<cfset LOCAL.qTemp[keyName][queryCount(LOCAL.qTemp)] = ARGUMENTS.o[keyName]>
					</cfloop>
				</cfif>
				<!--- add row to temp query from collection --->
				<cfset queryAddRow(LOCAL.qTemp)>
				<cfloop array="#VARIABLES.keys#" index="colName">
					<cfset LOCAL.qTemp[colName][queryCount(LOCAL.qTemp)] = VARIABLES.collection[colName][VARIABLES.collection.currentRow]>
				</cfloop>
			</cfloop>
			<!--- set collection to new query with extra row --->
			<cfset VARIABLES.collection = LOCAL.qTemp>
			
		<cfelseif isStruct(VARIABLES.collection)>
			<!--- NOT SUPPORTED FOR STRUCTURES --->
			<cfthrow message="UnsupportedOperationException">
			<cfset LOCAL.insertCount = 0>
			<cfloop collection="#ARGUMENTS.o#" item="s">
				<cfset arrayInsertAt(VARIABLES.keys,VARIABLES.n+LOCAL.insertCount,s)>
				<cfset LOCAL.insertCount = incrementValue(LOCAL.insertCount)>
			</cfloop>
			<cfset structAppend(VARIABLES.collection,ARGUMENTS.o)>
			
		<cfelseif isArray(VARIABLES.collection)>
			<cfset arrayInsertAt(VARIABLES.collection,VARIABLES.n+LOCAL.ammend,ARGUMENTS.o)>
			
		<cfelseif isSimpleValue(VARIABLES.collection)>
			<cfset VARIABLES.collection = listInsertAt(VARIABLES.collection,VARIABLES.n,ARGUMENTS.o)>
		</cfif>
		<!--- <cfset VARIABLES.n = incrementValue(VARIABLES.n)> --->
	</cffunction>
	
	<cffunction name="hasNext" output="false" returntype="boolean" access="public" hint="Returns true if this list iterator has more elements when traversing the list in the forward direction.">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>
		
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		<cfif isQuery(VARIABLES.collection)>
			<cfif n LTE VARIABLES.collection.getRowCount()>
				<cfset LOCAL.result = true>
			</cfif>
		<cfelseif isStruct(VARIABLES.collection)>
			<cfif n LTE arrayLen(VARIABLES.keys)>
				<cfset LOCAL.result = true>
			</cfif>
		<cfelseif isArray(VARIABLES.collection)>
			<cfif n LTE arrayLen(VARIABLES.collection)>
				<cfset LOCAL.result = true>
			</cfif>
		<cfelseif isSimpleValue(VARIABLES.collection)>
			<cfif n LTE listLen(VARIABLES.collection)>
				<cfset LOCAL.result = true>
			</cfif>
		</cfif>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="hasPrevious" output="false" returntype="boolean" access="public" hint="Returns true if this list iterator has more elements when traversing the list in the reverse direction.">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = false>
		
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		
		<cfif previousIndex() GT 0>
			<cfset LOCAL.result = true>
		</cfif>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="next" output="false" returntype="Any" access="public" hint="Returns the next element in the list.">
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		
		<!--- <cfif lastAction() EQ 'previous'>
			<!--- INCREMENT INDEX --->
			<!--- <cfset VARIABLES.n = incrementValue(VARIABLES.n)> --->
			<cfset VARIABLES.n = nextIndex()>
		</cfif> --->
		
		<cfset VARIABLES.n = nextIndex()>
		
		<cfif isQuery(VARIABLES.collection)>
			<cfif VARIABLES.n GT queryCount(VARIABLES.collection)>
				<cfthrow message="NoSuchElementException">
			</cfif>
			<!--- RETURN A BEAN OF THE QUERY ROW --->
			<cfset VARIABLES.object = createObject('component',"synapse.SynapseBean").init(VARIABLES.class)>
			<cfloop array="#VARIABLES.keys#" index="f">
				<cfinvoke component="#VARIABLES.object#" method="set#f#">
					<cfinvokeargument name="#f#" value="#VARIABLES.collection[f][n]#">
				</cfinvoke>
			</cfloop>
		<cfelseif isStruct(VARIABLES.collection)>
			<cfif VARIABLES.n GT structCount(VARIABLES.collection)>
				<cfthrow message="NoSuchElementException">
			</cfif>
			<!--- RETURN THE ELEMENT FOUND AT THE KEY FOUND AT POSITION n --->
			<!--- <cfset VARIABLES.object = VARIABLES.collection[VARIABLES.keys[VARIABLES.n]]> --->
			<!--- DECIDED TO RATHER RETURN KEY --->
			<cfset VARIABLES.object = VARIABLES.keys[VARIABLES.n]>
		<cfelseif isArray(VARIABLES.collection)>
			<cfif VARIABLES.n GT arrayLen(VARIABLES.collection)>
				<cfthrow message="NoSuchElementException">
			</cfif>
			<!--- RETURN ELEMENT FOUND AT POSITION n OF THE ARRAY --->
			<cfset VARIABLES.object = VARIABLES.collection[n]>
		<cfelseif isSimpleValue(VARIABLES.collection)>
			<cfif VARIABLES.n GT listLen(VARIABLES.collection)>
				<cfthrow message="NoSuchElementException">
			</cfif>
			<cfset VARIABLES.object = listGetAt(VARIABLES.collection,VARIABLES.n)>
		</cfif>
		
		<!--- <cfif lastAction() NEQ 'previous'>
			<!--- INCREMENT INDEX --->
			<cfset VARIABLES.n = incrementValue(VARIABLES.n)>
			<!--- <cfset VARIABLES.n = nextIndex()> --->
		</cfif> --->
		
		<cfset VARIABLES.n = incrementValue(VARIABLES.n)>
		
		<cfset lastAction('next')>
		
		<cfreturn VARIABLES.object>
	</cffunction>
	
	<cffunction name="nextIndex" output="false" returntype="numeric" access="public" hint="Returns the index of the element that would be returned by a subsequent call to next.">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = VARIABLES.n>
		<cfset LOCAL.listSize = 1>
		
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		
		<cfif lastAction() EQ 'previous'>
			<cfset LOCAL.result = incrementValue(LOCAL.result)>
		</cfif>
		
		<!--- DETERMINE MAX SIZE --->
		<cfif isQuery(VARIABLES.collection)>
			<cfset LOCAL.listSize = queryCount(VARIABLES.collection)>
		<cfelseif isStruct(VARIABLES.collection)>
			<cfset LOCAL.listSize = arrayLen(VARIABLES.keys)>
		<cfelseif isArray(VARIABLES.collection)>
			<cfset LOCAL.listSize = arrayLen(VARIABLES.collection)>
		<cfelseif isSimpleValue(VARIABLES.collection)>
			<cfset LOCAL.listSize = listLen(VARIABLES.collection)>
		</cfif>

		<!--- SET TO MAX SIZE OF LIST IF NEXT POSITION OVERSHOT BOUNDS  --->
		<cfif LOCAL.result GT LOCAL.listSize>
			<cfset LOCAL.result = LOCAL.listSize>
		</cfif>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="previous" output="false" returntype="Any" access="public" hint="Returns the previous element in the list.">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.p = previousIndex()>
		
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		
		<!--- <cfif lastAction() EQ 'next' AND hasPrevious()>
			<!--- DECREMENT INDEX --->
			<!--- <cfset VARIABLES.n = decrementValue(VARIABLES.n)> --->
			<cfset VARIABLES.n = decrementValue(previousIndex())>
		</cfif> --->
		
		<cfset VARIABLES.n = previousIndex()>
		
		<cfif VARIABLES.n LT 1>
			<cfthrow message="NoSuchElementException">
		</cfif>
		<cfif isQuery(VARIABLES.collection)>
			<!--- RETURN A BEAN OF THE QUERY ROW --->
			<cfset VARIABLES.object = createObject('component',"SynapseBean").init(VARIABLES.class)>
			<cfloop array="#VARIABLES.keys#" index="f">
				<cfinvoke component="#VARIABLES.object#" method="set#f#">
					<cfinvokeargument name="#f#" value="#VARIABLES.collection[f][LOCAL.p]#">
				</cfinvoke>
			</cfloop>
		<cfelseif isStruct(VARIABLES.collection)>
			<!--- RETURN THE ELEMENT FOUND AT THE KEY FOUND AT POSITION n --->
			<!--- <cfset VARIABLES.object = VARIABLES.collection[VARIABLES.keys[VARIABLES.n]]> --->
			<!--- DECIDED TO RATHER RETURN KEY --->
			<cfset VARIABLES.object = VARIABLES.keys[LOCAL.p]>
		<cfelseif isArray(VARIABLES.collection)>
			<!--- RETURN ELEMENT FOUND AT POSITION n OF THE ARRAY --->
			<cfset VARIABLES.object = VARIABLES.collection[LOCAL.p]>
		<cfelseif isSimpleValue(VARIABLES.collection)>
			<cfset VARIABLES.object = listGetAt(VARIABLES.collection,LOCAL.p)>
		</cfif>
		<!--- <cfif lastAction() NEQ 'next' AND hasPrevious()>
			<!--- INCREMENT INDEX --->
			<!--- <cfset VARIABLES.n = decrementValue(LOCAL.p)> --->
			<cfset VARIABLES.n = decrementValue(previousIndex())>
		</cfif> --->
		<cfset VARIABLES.n = decrementValue(VARIABLES.n)>
		<cfset lastAction('previous')>
		<cfreturn VARIABLES.object>
	</cffunction>
	
	<cffunction name="previousIndex" output="false" returntype="numeric" access="public" hint="Returns the index of the element that would be returned by a subsequent call to next.">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.ammend = -1>
		<cfif lastAction() EQ 'next'>
			<cfset LOCAL.ammend = -1>
		<cfelseif lastAction() EQ 'previous'>
			<cfset LOCAL.ammend = 0>
		</cfif>
		
		<cfset LOCAL.result = VARIABLES.n+LOCAL.ammend>

		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		
		<cfif LOCAL.result LT -1>
			<cfset LOCAL.result = -1>
		</cfif>
		
		<cfreturn LOCAL.result>
	</cffunction>
	
	<cffunction name="remove" output="false" returntype="void" access="public" hint="Removes from the list the last element that was returned by next or previous">
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		<!--- THROW EXCEPTION IF NEXT NOT CALLED OR PREVIOUS CALLED MORE OR EQUAL TIMES  --->
		<cfif VARIABLES.n EQ 0>
			<cfthrow message="IllegalStateException">
		</cfif>
		
		<cfif isQuery(VARIABLES.collection)>
			<!--- USE UNDERLYING JAVA QUERYTABLE TO DELETE RECORD --->
			<!--- <cfset VARIABLES.collection.deleteRows(JavaCast( "int", (VARIABLES.n - 1) ),JavaCast( "int", 1 )) /> --->
			<cfset VARIABLES.collection = queryRemoveRow(VARIABLES.collection,VARIABLES.n) />
		<cfelseif isStruct(VARIABLES.collection)>
			<!--- DELETE THE ELEMENT FOUND AT THE KEY FOUND AT POSITION n, AND THE KEY --->
			<cfset structDelete(VARIABLES.collection,VARIABLES.keys[VARIABLES.n])>
			<cfset arrayDeleteAt(VARIABLES.keys,VARIABLES.n)>
		<cfelseif isArray(VARIABLES.collection)>
			<!--- DELETE ELEMENT FOUND AT POSITION n OF THE ARRAY --->
			<cfset arrayDeleteAt(VARIABLES.collection,VARIABLES.n)>
		<cfelseif isSimpleValue(VARIABLES.collection)>
			<cfset VARIABLES.collection = listDeleteAt(VARIABLES.collection,VARIABLES.n)>
		</cfif>
		<cfset VARIABLES.n = decrementValue(VARIABLES.n)>
	</cffunction>
	
	<cffunction name="set" output="false" returntype="void" access="public" hint="Replaces the last element returned by next or previous with the specified element">
		<cfargument name="o" required="true" type="Any" hint="Overwrite this object to the current position of the iterator">
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		
		<cfset LOCAL.ammend = 0>
		<cfif lastAction() EQ 'next'>
			<cfset LOCAL.ammend = -1>
		<cfelseif lastAction() EQ 'previous' AND hasNext() AND hasPrevious()>
			<cfset LOCAL.ammend = 1>
		<cfelseif lastAction() EQ 'previous'>
			<cfset LOCAL.ammend = 0>
		</cfif>
		
		<!--- THROW EXCEPTION IF NEXT NOT CALLED OR PREVIOUS CALLED MORE OR EQUAL TIMES  --->
		<cfif VARIABLES.n EQ 0>
			<cfthrow message="IllegalStateException">
		</cfif>
		<!--- INSERT o INTO VARIABLES.collection AT THE CURRENT ITERATOR POSITION n --->
		<cfif isQuery(VARIABLES.collection)>
			<cfif NOT isStruct(ARGUMENTS.o)>
				<cfthrow message="IllegalArgumentException">
			</cfif>
			<!--- OVERWRITE QUERY ROW WITH STRUCT VALUES --->
			<cftry>
			<cfloop array="#VARIABLES.keys#" index="c">
				<cfset VARIABLES.collection[c][VARIABLES.n-1] = ARGUMENTS.o[c]>
			</cfloop>
			<cfcatch type="any">
				<cfthrow message="IllegalArgumentException: #cfcatch.message#">
			</cfcatch>
			</cftry>
		<cfelseif isStruct(VARIABLES.collection)>
			<!--- NOT SUPPORTED FOR STRUCTURES --->
			<cfthrow message="UnsupportedOperationException">
		<cfelseif isArray(VARIABLES.collection)>
			<cfset LOCAL.curIndex = (VARIABLES.n+LOCAL.ammend)>
			<!--- <cfthrow message="#LOCAL.curIndex#"> --->
			<cfset VARIABLES.collection[LOCAL.curIndex] = ARGUMENTS.o>
		<cfelseif isSimpleValue(VARIABLES.collection)>
			<cfset VARIABLES.collection = listSetAt(VARIABLES.collection,VARIABLES.n-1,ARGUMENTS.o)>
		</cfif>
	</cffunction>
	
===================================================================================================================
<!--- EXTRA FOR CONVENIENCE AND TESTING --->
	<cffunction name="reset" output="false" returntype="void" access="public" hint="Resets feeping current state of collection.">
		<cfset init(VARIABLES.collection,VARIABLES.class)>
	</cffunction>

	<!--- FIRST --->
	<cffunction name="first" output="false" returntype="Any" access="public" hint="Returns the first element in the list.">
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		<cfset lastAction('next')>
		<cfset VARIABLES.n = 1>
		<cfif hasNext()>
			<cfreturn next()>
		<cfelse>
			<cfreturn VARIABLES.class.getBean()>
		</cfif>
	</cffunction>
	
	<!--- LAST --->
	<cffunction name="last" output="false" returntype="Any" access="public" hint="Returns the next element in the list.">
		<!--- CHECK THAT INITIALIZED --->
		<cfset checkInitialzed()>
		<cfset lastAction('next')>
		
		<cfset VARIABLES.n = collectionLen()>

		<cfif hasNext()>
			<cfreturn next()>
		<cfelse>
			<cfreturn VARIABLES.class.getBean()>
		</cfif>
	</cffunction>
<!--- GET COLLECTION --->
	<cffunction name="getCollection" output="false" returntype="Any" access="public" hint="Returns the collection.">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.result = VARIABLES.collection>

		<cfreturn LOCAL.result>
	</cffunction>

	<cffunction name="index" output="false" returntype="Numeric" access="public" hint="Returns the element position in the list.">
		<cfargument name="pos" required="false" type="Numeric">
		<cfset var LOCAL = structNew()>
		<cfif structKeyExists(ARGUMENTS,'pos')>
			<cfset VARIABLES.n = ARGUMENTS.pos>
		</cfif>
		<cfset LOCAL.pos = VARIABLES.n>
		<cfreturn LOCAL.pos>
	</cffunction>
===================================================================================================================
<!--- PRIVATE FUNCTIONS --->
	<cffunction name="lastAction" output="false" returntype="Any" access="private" hint="I increment the pointer">
		<cfargument name="action" required="false" type="String">
		<cfset var LOCAL = structNew()>
		<cfif structKeyExists(ARGUMENTS,'action')>
			<cfset VARIABLES._lastAction = ARGUMENTS.action>
		</cfif>
		<cfset LOCAL.action = VARIABLES._lastAction>
		<cfreturn LOCAL.action>
	</cffunction>
	
	<cffunction name="checkInitialzed" output="false" returntype="void" access="private" hint="Check that init has been called">
		<cfif NOT structKeyExists(VARIABLES,'n')>
			<cfthrow message="ListIterator must be initialized before use. Call init(collection).">
		</cfif>
	</cffunction>
	
	<cffunction name="queryCount" access="private" returntype="Numeric">
		<cfargument name="query" type="query" required="true">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.queryCount = 0>
		<cfif SERVER.coldfusion.productname IS 'ColdFusion Server'>
			<cfset LOCAL.queryCount = ARGUMENTS.query.recordCount>
		<cfelse>
			<cfset LOCAL.queryCount = queryRecordCount(ARGUMENTS.query)>
		</cfif>
		<cfreturn LOCAL.queryCount>
	</cffunction>

	<cffunction name="queryRemoveRow" access="private" returntype="Numeric">
		<cfargument name="query" type="query" required="true" hint="Query to remove row from">
		<cfargument name="row" type="numeric" required="true" hint="Row number to remove">
		
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.row = decrementValue(ARGUMENTS.row)>
		<cfset LOCAL.qTemp = ARGUMENTS.query>
		<cfif SERVER.coldfusion.productname IS 'ColdFusion Server'>
			<cfset LOCAL.qTemp.deleteRows(JavaCast( "int",LOCAL.row),JavaCast( "int",1)) />
		<cfelse>
			<cfset LOCAL.qTemp.removeRow(JavaCast( "int",LOCAL.row)) />
		</cfif>
		<cfreturn LOCAL.qTemp>
	</cffunction>

	<cffunction name="collectionLen" access="private" returntype="Numeric">
		<cfset var LOCAL = structNew()>
		<cfset LOCAL.length = 0>
		
		<cfif isQuery(VARIABLES.collection)>
			<cfset LOCAL.length = queryCount(VARIABLES.collection)>
		<cfelseif isStruct(VARIABLES.collection)>
			<cfset LOCAL.length = structCount(VARIABLES.collection)>
		<cfelseif isArray(VARIABLES.collection)>
			<cfset LOCAL.length = arrayLen(VARIABLES.collection)>
		<cfelseif isSimpleValue(VARIABLES.collection)>
			<cfset LOCAL.length = listLen(VARIABLES.collection)>
		</cfif>
		
		<cfreturn LOCAL.length>
	</cffunction>
</cfcomponent>