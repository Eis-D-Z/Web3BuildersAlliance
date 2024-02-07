module kiosk_jam::trading {
    use sui::coin;
    use sui::sui::SUI;
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::transfer_policy::{Self as tp, TransferPolicy};
    use sui::tx_context::{TxContext, Self};
    use sui::package::{Self, Publisher};

    use std::string::{String};


    struct TRADING has drop {}

    struct Registry has key {
        id: UID,
        tp: TransferPolicy<NFT> // this will be empty
    }

    struct PresentBox has key {
        id: UID,
        nft: NFT
    }

    struct NFT has key, store {
        id: UID,
        age: u64,
        name: String
    }


    fun init (otw: TRADING, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);

        let (transfer_policy, tp_cap) = tp::new<NFT>(&publisher, ctx);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(tp_cap, tx_context::sender(ctx));

        transfer::public_share_object(transfer_policy);

    }


    public fun mint (age: u64, name: String, ctx: &mut TxContext) {
        let nft =  NFT {
                    id: object::new(ctx),
                    age,
                    name
        };

        let box = PresentBox {
            id: object::new(ctx),
            nft
        };

        transfer::transfer(box, tx_context::sender(ctx));
    }

    public fun unwrap (
        present_box: PresentBox,
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        tp: &TransferPolicy<NFT>) {
        let PresentBox {id, nft} = present_box;
        object::delete(id);
        kiosk::lock(kiosk, kiosk_cap, tp, nft);
    }


    public fun create_empty_policy(publisher: &Publisher, ctx: &mut TxContext) {
        
        let (transfer_policy, tp_cap) = tp::new<NFT>(publisher, ctx);
        let registry = Registry {
            id: object::new(ctx),
            tp: transfer_policy
        };

        transfer::public_transfer(tp_cap, tx_context::sender(ctx));
        transfer::share_object(registry);
    }

    public fun burn_from_kiosk (
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        nft_id: ID,
        registry: &mut Registry,
        ctx: &mut TxContext) {
        let purchase_cap = kiosk::list_with_purchase_cap<NFT>(kiosk, kiosk_cap, nft_id, 0, ctx);
        let (nft, transfer_request) = 
                  kiosk::purchase_with_cap<NFT>(kiosk, purchase_cap,coin::zero<SUI>(ctx));
        tp::confirm_request<NFT>(&registry.tp, transfer_request);
        let NFT {id, age: _, name: _} = nft;
        object::delete(id);
    }


}