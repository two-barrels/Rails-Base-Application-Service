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

      @domain_id = domain_result&.[](0)&.dig("id")
    end

    def verify_domain_transaction
      fail!("Transfer failed for #{fqdn}") unless domain_id
    end

    def update_service_with_domain_info
      associated_service.update!({
         data: {
           domain: {
             fqdn:,
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
