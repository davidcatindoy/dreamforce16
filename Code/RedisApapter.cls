global class RedisAdapter extends DataSource.Connection {
    
    private static String DB_BASEURL = 'https://cloud-airlines.herokuapp.com/';
    private static String FLIGHTS_TABLE = 'Redis_Flight';
    private static String BOOKINGS_TABLE = 'Redis_Bookings';
    private static String FLIGHTS_PATH = 'flights/';
    private static String BOOKINGS_PATH = 'bookings/';

    /***********  EXTERNAL SCHEMA DECLARATION      *********************************************************************************/
    override global List<DataSource.Table> sync() {
        List<DataSource.Table> tables = new List<DataSource.Table>();
        List<DataSource.Column>columns = new List<DataSource.Column>();
        
        //FLIGHTS TABLE
        columns.add(DataSource.Column.text('ExternalId', 255));// MANDATORY FIELD FOR UNIQUE IDENTIFICATION 
        columns.add(DataSource.Column.text('Code',255));
        columns.add(DataSource.Column.text('Origin', 255));
        columns.add(DataSource.Column.text('Destiny', 255));
        columns.add(DataSource.Column.integer('Capacity',10));
        columns.add(DataSource.Column.integer('Bookings',10));
        columns.add(DataSource.Column.text('Status',255));
        columns.add(DataSource.Column.get('Departure','Departure','Flight Date', true, true, DataSource.DataType.DATETIME_TYPE, 255,0));
        columns.add(DataSource.Column.url('DisplayUrl'));
        
        tables.add(DataSource.Table.get('Redis_Flight','Flight', 'Flights','Flights from Heroku Redis External DB', 'Code' ,columns));     
        columns = new List<DataSource.Column>();

        //BOOKINGS TABLE
        columns.add(DataSource.Column.text('ExternalId', 255));// MANDATORY FIELD FOR UNIQUE IDENTIFICATION
        columns.add(DataSource.Column.text('Code',255));
        columns.add(DataSource.Column.text('First Name', 255));
        columns.add(DataSource.Column.text('Last Name', 255));
        columns.add(DataSource.Column.text('Email',255));
        columns.add(DataSource.Column.text('Flight',255));
        columns.add(DataSource.Column.integer('Credit Card',18));
        columns.add(DataSource.Column.get('Date','Date','Purchase Date', true, true, DataSource.DataType.DATETIME_TYPE, 255,0));
        columns.add(DataSource.Column.url('DisplayUrl'));

        tables.add(DataSource.Table.get('Redis_Bookings','Booking', 'Bookings','Bookings from Heroku Redis External DB', 'Code' ,columns));

        return tables;
    }
    
    override global DataSource.TableResult query(DataSource.QueryContext table) {
        /**************** REDIS FLIGHTS INTERACTION                   ********************************************************************/
        if(table.tableSelection.tableSelected == 'Redis_Flight'){
            
            if(table.tableSelection.filter == null  || table.tableSelection.filter.columnValue==null)//USING A LIST VIEW
                return DataSource.TableResult.get(table,getRows(FLIGHTS_PATH));
            
            else{
                if(table.tableSelection.filter.columnName == 'ExternalId')//SHOWING AN EXTERNAL RECORD DETAIL PAGE
                    return DataSource.TableResult.get(table,getValue(FLIGHTS_PATH, 
                                                                    (String) table.tableSelection.filter.columnValue));
                
                else//SHOWING AN EXTERNAL RECORD DETAIL PAGE WITH A FILTER
                    return DataSource.TableResult.get(table,getRows(FLIGHTS_PATH+
                                                    '?filter='+String.valueOf(table.tableSelection.filter.columnName).toLowerCase()+
                                                     '&value='+
                                                     (String) table.tableSelection.filter.columnValue));
            }
        }

        /**************** REDIS BOOKINGS INTERACTION                   ********************************************************************/
        else if(table.tableSelection.tableSelected == 'Redis_Bookings'){
            if(table.tableSelection.filter == null  || table.tableSelection.filter.columnValue==null)//USING A LIST VIEW
                return DataSource.TableResult.get(table,getRows(BOOKINGS_PATH));
            
            else{
                if(table.tableSelection.filter.columnName == 'ExternalId')//SHOWING AN EXTERNAL RECORD DETAIL PAGE
                    return DataSource.TableResult.get(table,getValue(BOOKINGS_PATH, 
                                                                    (String) table.tableSelection.filter.columnValue));
                
                else//SHOWING AN EXTERNAL RECORD DETAIL PAGE WITH A FILTER
                    return DataSource.TableResult.get(table,getRows(BOOKINGS_PATH+
                                                    '?filter='+String.valueOf(table.tableSelection.filter.columnName).toLowerCase()+
                                                     '&value='+
                                                     (String) table.tableSelection.filter.columnValue));       
            }
        }  
        return null;        
    }

    override global List<DataSource.TableResult> search(DataSource.SearchContext c) {//FOR GLOBAL SEARCH THAT INVOLVES BOTH EXTERNAL OBJECTS
        List<DataSource.TableResult> results = new List<DataSource.TableResult>();
        for (DataSource.TableSelection tableSelection : c.tableSelections) {
            
            if(tableSelection.tableSelected == 'FLIGHTS_TABLE')
                results.add(DataSource.TableResult.get(tableSelection, getRows(FLIGHTS_PATH)));
            
            else if(tableSelection.tableSelected == 'BOOKINGS_TABLE')
                results.add(DataSource.TableResult.get(tableSelection, getRows(FLIGHTS_PATH)));
        }
        return results;
    }

    global override List<DataSource.UpsertResult> upsertRows(DataSource.UpsertContext context) {  
        List<DataSource.UpsertResult> results = new List<DataSource.UpsertResult>();   
       List<Map<String, Object>> rows = context.rows;

        if (context.tableSelected == FLIGHTS_TABLE) {
            for (Map<String, Object> row : rows){
                //if (row.get('ExternalId') == null){  TO KNOW IF IT IS UPDATE OR AN INSERT
                HttpResponse response = insertRow(FLIGHTS_PATH,serilizeFlight(row), (String) row.get('Code'));
                results.add(handleUpsertResponse(response));
            }            
       
       }else if (context.tableSelected == BOOKINGS_TABLE) {
            for (Map<String, Object> row : rows){
                HttpResponse response = insertRow(BOOKINGS_PATH,serilizeBooking(row), (String) row.get('Code'));
                results.add(handleUpsertResponse(response));
            }            
       } 
       
       return results;
    }

    global override List<DataSource.DeleteResult> deleteRows(DataSource.DeleteContext  context) {
        List<DataSource.DeleteResult> results = new List<DataSource.DeleteResult>(); 

        if (context.tableSelected == FLIGHTS_TABLE){
            for (String externalId : context.externalIds){
                HttpResponse response = deleteRow(FLIGHTS_PATH,externalId);
                results.add(handleDeleteResponse(response));     
            }


        }else if (context.tableSelected == BOOKINGS_TABLE){
            for (String externalId : context.externalIds){
                HttpResponse response = deleteRow(BOOKINGS_PATH,externalId);
                results.add(handleDeleteResponse(response));     
            } 
        }
        return results;
    }

    private DataSource.UpsertResult handleUpsertResponse(HttpResponse response){
        Map<String, Object> m = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
              
        if (response.getStatusCode() == 201)//UPSERTED CORRECTLY
            return DataSource.UpsertResult.success(String.valueOf(m.get('result')));
        else 
            return DataSource.UpsertResult.failure(String.valueOf(m.get('error')), 'UPSERT FAILED: ' + response.getStatusCode());
    }

    private DataSource.DeleteResult handleDeleteResponse(HttpResponse response){
        Map<String, Object> m = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
              
        if (response.getStatusCode() == 200)//DELETED CORRECTLY
            return DataSource.DeleteResult.success(String.valueOf(m.get('result')));
        else 
            return DataSource.DeleteResult.failure(String.valueOf(m.get('error')), 'DELETE FAILED: ' + response.getStatusCode());
    }


     private HttpResponse deleteRow(String path,String code){
        HttpRequest request = new HttpRequest();
        request.setEndpoint(DB_BASEURL+path+code);
        request.setMethod('DELETE');
        request.setTimeout(120000);
        Http h = new Http();
        HttpResponse response = h.send(request);
        return response;
    }

    private HttpResponse insertRow(String path,String jsonBody,String code){
        HttpRequest request = new HttpRequest();
        request.setEndpoint(DB_BASEURL+path+code);
        request.setHeader('Content-Type', 'application/json');
        request.setMethod('POST');
        request.setTimeout(120000);
        request.setBody(jsonBody);
        Http h = new Http();
        HttpResponse response = h.send(request);
        return response;
    }
    
    private List<Map<String,Object>> getRows(String path){
        HttpRequest request = new HttpRequest();
        request.setEndpoint(DB_BASEURL+path);
        request.setMethod('GET');
        request.setTimeout(120000);
        Http h = new Http();
        HttpResponse response = h.send(request);
        
        List<Map<String,Object>> rows = new List<Map<String,Object>>();

        if(response.getStatusCode() != 200)
            return rows;

        Map<String, Object> m =  (Map<String, Object>) JSON.deserializeUntyped(response.getBody());    
        List<Object> result = (List<Object>) m.get('result');

        for(Object o : result){
            if(path.contains(FLIGHTS_PATH)) 
                rows.add(deserializeFlight(o));
            else if(path.contains(BOOKINGS_PATH))
                rows.add(deserializeBooking(o));    
        }
        
        return rows;   
        
    }
    
    private List<Map<String,Object>> getValue(String path,String index){
        List<Map<String,Object>> rows = new List<Map<String,Object>>();
        HttpRequest request = new HttpRequest();

        request.setEndpoint(DB_BASEURL+path+index);
        request.setMethod('GET');
        request.setTimeout(120000);
        Http h = new Http();
        HttpResponse response = h.send(request);

        if(response.getStatusCode() != 200)
            return new List<Map<String,Object>>();
        
        Object o =  (Object) JSON.deserializeUntyped(response.getBody());

        if(path == FLIGHTS_PATH)
            rows.add(deserializeFlight(o));
        else if(path == BOOKINGS_PATH)
            rows.add(deserializeBooking(o));
        
        return rows;
    }
    
    private static DateTime parseDateTime(String value){
        Datetime output = null;
        if(String.isNotBlank(value)){
            try{
                output = (DateTime)JSON.deserialize('"'+value+'"', DateTime.class);
            }catch(Exception e){}
        }
        return output;
    }


     private Map<String,Object> deserializeFlight(Object obj){
        Map<String,Object> jsonObject = (Map<String,Object>)obj;
        Map<String,Object> row = new Map<String,Object>();
        
        row.put('Origin',jsonObject.get('origin'));
        row.put('Destiny',jsonObject.get('destiny'));
        row.put('Departure',parseDateTime(String.valueOf(jsonObject.get('departure'))));
        row.put('ExternalId', jsonObject.get('code'));
        row.put('Status',jsonObject.get('status'));
        row.put('Capacity',jsonObject.get('capacity'));
        row.put('Bookings',jsonObject.get('bookings'));
        row.put('DisplayUrl',DB_BASEURL+FLIGHTS_PATH+jsonObject.get('code'));
        row.put('Code',jsonObject.get('code'));
        return row;
    }

    private String serilizeFlight(Map<String, Object> row){
        Map<String,Object> flight = new Map<String,Object>();

        flight.put('code', row.get('Code'));
        flight.put('origin', row.get('Origin'));
        flight.put('destiny', row.get('Destiny'));
        flight.put('departure', row.get('Departure'));
        flight.put('status', row.get('Status'));
        flight.put('capacity', row.get('Capacity'));
        flight.put('bookings', row.get('Bookings'));

        return JSON.serialize(flight);
    }

    private Map<String,Object> deserializeBooking(Object obj){
        Map<String,Object> jsonObject = (Map<String,Object>)obj;
        Map<String,Object> row = new Map<String,Object>();

        row.put('First Name',jsonObject.get('firstname'));
        row.put('Last Name',jsonObject.get('lastname'));
        row.put('Date',parseDateTime(String.valueOf(jsonObject.get('purchasedate'))));
        row.put('ExternalId', jsonObject.get('code'));
        row.put('Email',jsonObject.get('email'));
        row.put('Credit Card',jsonObject.get('creditcard'));
        row.put('Flight',jsonObject.get('flight'));
        row.put('DisplayUrl',DB_BASEURL+BOOKINGS_PATH+jsonObject.get('code'));
        row.put('Code',jsonObject.get('code'));

        System.debug('deserialize :'+row);
        return row;
    }

    private String serilizeBooking(Map<String, Object> row){
        Map<String,Object> booking = new Map<String,Object>();

        booking.put('firstname', row.get('First Name'));
        booking.put('lastname', row.get('Last Name'));
        booking.put('purchasedate', row.get('Date'));
        booking.put('email', row.get('Email'));
        booking.put('creditcard', row.get('Credit Card'));
        booking.put('code', row.get('Code'));
        booking.put('flight', row.get('Flight'));
        return JSON.serialize(booking);
    }      

}