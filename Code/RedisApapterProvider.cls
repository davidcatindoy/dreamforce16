global class RedisAdapterProvider extends DataSource.Provider { 
      override global List<DataSource.AuthenticationCapability> getAuthenticationCapabilities() {
        /***********  AUTHENTICATION DECLARATION      *********************************************************************************/
       
        List<DataSource.AuthenticationCapability> capabilities = new List<DataSource.AuthenticationCapability>();
        capabilities.add(DataSource.AuthenticationCapability.ANONYMOUS);
        //capabilities.add(DataSource.AuthenticationCapability.BASIC);
        //capabilities.add(DataSource.AuthenticationCapability.CERTIFICATE);
        //capabilities.add(DataSource.AuthenticationCapability.OAUTH);
        return capabilities;
      }
      
      override global List<DataSource.Capability> getCapabilities() {
        /***********  CAPABILITIES DECLARATION        *********************************************************************************/
        
        List<DataSource.Capability> capabilities = new List<DataSource.Capability>();
        capabilities.add(DataSource.Capability.ROW_QUERY);
        capabilities.add(DataSource.Capability.SEARCH);
        capabilities.add(DataSource.Capability.ROW_CREATE);
        capabilities.add(DataSource.Capability.ROW_UPDATE);
        capabilities.add(DataSource.Capability.ROW_DELETE);
        return capabilities;
      }
      override global DataSource.Connection getConnection(DataSource.ConnectionParams connectionParams) {
          return new RedisAdapter();
      }
}