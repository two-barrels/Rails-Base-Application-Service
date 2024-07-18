# ServiceBase and DryService in Rails

Welcome to the `ServiceBase` and `DryService` README! This guide will walk you through the usage and benefits of these modules in a Rails application and why we use it at Two Barrels!

## Introduction

The `DryService` module and `ServiceBase` class aim to streamline service object creation in Rails by integrating `dry-validation` for input validation. This ensures consistency and predictability across different contexts (controllers, background jobs, tests, etc.) by validating inputs directly within the service classes.

## Why Validate This Way?

Traditionally, input validation in Rails has relied on `ActionController::Parameters` within controllers, often neglecting validation in other contexts like background jobs or inter-service communication. By incorporating validation directly into service objects, we achieve:

- Consistent validation across different contexts
- Automatic creation of accessor methods for validated parameters
- Improved readability and maintainability of service code

## How It Works

The `ServiceBase` class includes the `DryService` module, which provides validation capabilities using `dry-validation`. Here's a quick rundown:

1. **Define a Contract**: Use the `contract` method to specify expected parameters and their validations.
2. **Validate Parameters**: The `validate_params!` method ensures that parameters conform to the defined contract, raising a `ValidationError` if they do not.
3. **Implement `setup` and `execute` Methods**: Child classes must define these methods to perform service-specific logic.

### Example

Here's an example service class:

```ruby
module Checkout::Products
  class DomainCheckoutService < ::ServiceBase

    contract do
      params do
        required(:shopping_cart_item).value(type?: ShoppingCartItem)
        required(:contact).filled(:hash)
      end
    end

    def setup
      fail!("FQDN is required") unless fqdn.present?
      fail!("Service was not created") unless associated_service.present?
    end

    def execute
      create_or_transfer_domain
      verify_domain_transaction
      update_service_with_domain_info
    end

    private

    attr_reader :fqdn, :transfer_code, :associated_service, :domain_id

    def create_or_transfer_domain
      return initiate_transfer_domain if domain_transfer?

      create_new_domain
    end

    def create_new_domain
      domain_result = Domains::CreateDomainService.new(
        account_id: Current.account_id,
        fqdn: fqdn,
        contact_id: contact.dig(:data, :id),
        service_id: associated_service.id
      ).run!

      @domain_id = domain_result&.dig("id")
    end

    def initiate_transfer_domain
      fail!("Transfer code is required") unless transfer_code.present?

      payload = {
        "account_id": Current.account_id,
        "domains": [
          {
            "fqdn": fqdn,
            "transfer_code": transfer_code,
            "service_id": associated_service.id,
            "contact_id": contact.dig(:data, :id),
          },
        ]
      }
      domain_result = Domains::InitiateTransferService.new(payload).run!

      @domain_id = domain_result&. &.dig("id")
    end

    def verify_domain_transaction
      fail!("Transfer failed for #{fqdn}") unless domain_id
    end

    def update_service_with_domain_info
      associated_service.update!({
        data: {
          domain: {
            fqdn: fqdn,
            id: domain_id,
          }
        }
      })
    end

    def domain_transfer?
      @transfer ||= shopping_cart_item.data.dig("meta", "is_transfer") == true
    end

    def fqdn
      @fqdn ||= shopping_cart_item.data.dig("meta", "domain")
    end

    def transfer_code
      @transfer_code ||= shopping_cart_item.dig("meta", "transfer_code")
    end

    def associated_service
      @service ||= shopping_cart_item.order_item.renewable_service
    end
  end
end
```


## Installation
Add dry-validation to your Gemfile:

ruby
Copy code
gem 'dry-validation'
Usage
Create your service classes under `app/services/` and include `ServiceBase`. Define your contract and implement the setup and execute methods.

## Benefits
- Consistent Validation: Ensures input validation is consistent across all service calls.
- Automatic Accessors: Creates accessor methods for validated parameters, simplifying service logic.
- Clear Error Handling: Provides a structured way to handle and communicate validation errors.
### Error Handling
- Custom errors can be defined within your service classes to handle specific failure scenarios:

```ruby
class DocumentLockService < ServiceBase
  class DocumentLockServiceError < ServiceError; end
  class DocumentNotFoundError < DocumentLockServiceError; end

  def setup
    fail!("Document does not exist", DocumentNotFoundError) if @document.blank?
  end
end
```

## Declaring Output
Clearly define the shape of your `@result` in the setup method to improve readability and predictability:

```ruby
def setup
  @result = {
    name: '',
    description: '',
    price: '',
    data: {}
  }
end
```

## Executing Services
Execute services using:
```ruby
result = YourService.new(params).run!
```

## Advanced Contract Example
You can create standalone contracts and use them within your services:

```ruby
module Schemas
  module StorefrontVariant
    Create = Dry::Schema.Params do
      required(:storefront_id).filled(:string)
      required(:storefront_variant).hash do
        required(:vendor_product_id).filled(:string)
        required(:name).filled(:string)
        optional(:description).filled(:string)
      end
    end
  end
end

contract do
  params(Schemas::StorefrontVariant::Create)
end
```

## Conclusion
By integrating `dry-validation` within service objects, we achieve a robust and maintainable way to handle input validation in Rails applications. This approach ensures consistent validation, clear error handling, and a predictable service structure, making your codebase more resilient and easier to work with. Happy coding! 🚀
