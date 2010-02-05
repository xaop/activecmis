module ActiveCMIS
  # The base class for all CMIS exceptions,
  # HTTP communication errors and the like are not catched by this
  class Error < StandardError
    # === Cause
    # One or more of the input parameters to the service method is missing or invalid
    class InvalidArgument < Exception; end

    # === Cause
    # The service call has specified an object that does not exist in the Repository
    class ObjectNotFound < Exception; end

    # === Cause
    # The service method invoked requires an optional capability not supported by the repository
    class NotSupported < Exception; end

    # === Cause
    # The caller of the service method does not have sufficient permissions to perform the operation
    class PermissionDenied < Exception; end

    # === Cause
    # Any cause not expressible by another CMIS exception
    class Runtime < Exception; end

    # === Intent
    # The operation violates a Repository- or Object-level constraint defined in the CMIS domain model
    #
    # === Methods
    # see the CMIS specification
    class Constraint < Exception; end
    # === Intent
    # The operation attempts to set the content stream for a Document
    # that already has a content stream without explicitly specifying the
    # "overwriteFlag" parameter
    #
    # === Methods
    # see the CMIS specification
    class ContentAlreadyExists < Exception; end
    # === Intent
    # The property filter or rendition filter input to the operation is not valid
    #
    # === Methods
    # see the CMIS specification
    class FilterNotValid < Exception; end
    # === Intent
    # The repository is not able to store the object that the user is creating/updating due to a name constraint violation
    #
    # === Methods
    # see the CMIS specification
    class NameConstraintViolation < Exception; end
    # === Intent
    # The repository is not able to store the object that the user is creating/updating due to an internal storage problam
    #
    # === Methods
    # see the CMIS specification
    class Storage < Exception; end
    # === Intent
    #
    #
    # === Methods
    # see the CMIS specification
    class StreamNotSupported < Exception; end
    # === Intent
    #
    #
    # === Methods
    # see the CMIS specification
    class UpdateConflict < Exception; end
    # === Intent
    #
    #
    # === Methods
    # see the CMIS specification
    class Versioning < Exception; end
  end
end
