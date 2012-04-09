Batch Entry for Salesforce.com
==============================

Salesforce.com data entry is awesome, and sometimes you need to crank through creating 100 records and you want a faster interface.
Spreadsheet-like interfaces don't work well on the web where you might lose your connection at any time. To do an interface like that right, you need to save continually.
Batch Entry for Salesforce.com is a lightweight way to work in fast batches.

Some features:

* Rapid data entry for any object and any fields
* Highly configurable via a custom setting
* Work in batches that can be saved and returned to later
* Pin field values that are constant in the batch to save typing
* See a list of all records created in the Batch

Screencast
----------
http://www.screencast.com/t/Nh26KHul8

Installation
------------
1. Deploy this code to a Salesforce organization
2. Make included tabs and objects visible as desired
3. Create lookup field to Batch__c for any object you want to do batch entry on (see contact object for example)
4. Modify the custom setting for each object you want to do batch entry on

Meta 
----
Many thanks to our awesome contributors:

* Mike Fulmore <mfullmore@fb.com>
* Evan Callahan <evan@groundwire.org>
* Veronica Waters <veronicaw@npowernw.org>
* Bergen Moore <bergen@bergenmoore.com>
* Derek D'Souza <ddsouza@salesforce.com>
* Kevin Bromer <kbromer@salesforce.com>
* Steve Andersen <steve.andersen@salesforce.com>

Released under the [BSD license](http://www.opensource.org/licenses/BSD-3-Clause).

Release Notes 
-------------
* 1.1 (4/9/12)<br/>
<i> Setting to override Opportunity naming behavior </i><br/>
<i> Refresh save list to display formula/trigger modified fields </i><br/>
<i> Updates to 'About Batch Entry' tab </i><br/>
<i> Dynamically query Batch__c field so custom fields can be added to fieldset </i><br/>


