module ActiveCMIS
  # This module defines namespaces that often occur in the REST/Atompub API to CMIS
  module NS
    CMIS_CORE = "http://docs.oasis-open.org/ns/cmis/core/200908/"
    CMIS_REST = "http://docs.oasis-open.org/ns/cmis/restatom/200908/"
    CMIS_MESSAGING = "http://docs.oasis-open.org/ns/cmis/messaging/200908/"
    APP = "http://www.w3.org/2007/app"
    ATOM = "http://www.w3.org/2005/Atom"

    COMBINED = {
      "c" => CMIS_CORE,
      "cra" => CMIS_REST,
      "cm" => CMIS_MESSAGING,
      "app" => APP,
      "at" => ATOM
    }
  end
end
