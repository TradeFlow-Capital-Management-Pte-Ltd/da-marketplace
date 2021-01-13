import React, { useState, useEffect } from 'react'
import { useHistory, useLocation } from 'react-router-dom'

import { useParty, useLedger, useStreamQueries } from '@daml/react'
import { Id } from '@daml.js/da-marketplace/lib/DA/Finance/Types/module'
import { Exchange } from '@daml.js/da-marketplace/lib/Marketplace/Exchange'
import { ExchangeParticipant } from '@daml.js/da-marketplace/lib/Marketplace/ExchangeParticipant'
import { Token } from '@daml.js/da-marketplace/lib/Marketplace/Token'
import { Order } from '@daml.js/da-marketplace/lib/Marketplace/Trading'

import { ExchangeIcon } from '../../icons/Icons'

import { DepositInfo, wrapDamlTuple, makeContractInfo } from '../common/damlTypes'
import { useOperator } from '../common/common'
import PageSection from '../common/PageSection'
import OrderLadder, { MarketDataMap } from '../common/OrderLadder'
import Page from '../common/Page'

import OrderForm from './OrderForm'

import './InvestorTrade.scss'

type Props = {
    deposits: DepositInfo[];
    sideNav: React.ReactElement;
    onLogout: () => void;
}

type LocationState = {
    exchange?: Exchange;
    tokenPair?: Id[];
}

export enum OrderKind {
    BID = 'bid',
    OFFER = 'offer'
}

const filterDepositsForOrder = (deposits: DepositInfo[], accountLabel: string, symbol: string) => {
    return deposits
        .filter(d => d.contractData.account.id.label === accountLabel)
        .filter(d => d.contractData.asset.id.label === symbol);
}

const InvestorTrade: React.FC<Props> = ({ deposits, sideNav, onLogout }) => {
    const [ bidDeposits, setBidDeposits ] = useState<DepositInfo[]>([]);
    const [ offerDeposits, setOfferDeposits ] = useState<DepositInfo[]>([]);

    const location = useLocation<LocationState>();
    const history = useHistory();
    const operator = useOperator();
    const investor = useParty();
    const ledger = useLedger();

    const allOrders = useStreamQueries(Order, () => [], [], (e) => {
        console.log("Unexpected close from Order: ", e);
    }).contracts.map(makeContractInfo);

    const marketData = allOrders.reduce((map, order) => {
        const { price } = order.contractData;
        const kind = order.contractData.isBid ? OrderKind.BID : OrderKind.OFFER;

        const qtyOrders = map[+price]?.qtyOrders || 0;
        const existingKind = map[+price]?.kind;

        if (existingKind && existingKind !== kind) {
            throw new Error('uh oh');
        }

        return { ...map, [+price]: { kind, qtyOrders: qtyOrders + 1, price: +price } };
    }, {} as MarketDataMap)

    const exchangeData = location.state && location.state.exchange;
    const tokenPair = location.state && location.state.tokenPair;

    if (!exchangeData || !tokenPair) {
        history.push('/role/investor');
        throw new Error('No exchange found.');
    }

    const { exchange } = exchangeData;
    const [ base, quote ] = tokenPair.map(t => t.label);

    const tokens = useStreamQueries(Token).contracts.map(makeContractInfo);

    const basePrecision = Number(tokens.find(token => token.contractData.id.label === tokenPair[0].label)?.contractData.quantityPrecision) || 0;
    const quotePrecision = Number(tokens.find(token => token.contractData.id.label === tokenPair[1].label)?.contractData.quantityPrecision) || 0;

    useEffect(() => {
        const label = `'${investor}'@'${exchange}'`;
        setBidDeposits(filterDepositsForOrder(deposits, label, quote));
        setOfferDeposits(filterDepositsForOrder(deposits, label, base));
    }, [ deposits, base, quote, investor, exchange ]);

    const placeBid = async (depositCids: string[], price: string, amount: string) => {
        const key = wrapDamlTuple([exchange, operator, investor]);
        const args = {
            price,
            amount,
            depositCids,
            pair: wrapDamlTuple(tokenPair)
        };

        await ledger.exerciseByKey(ExchangeParticipant.ExchangeParticipant_PlaceBid, key, args);
    }

    const placeOffer = async (depositCids: string[], price: string, amount: string) => {
        const key = wrapDamlTuple([exchange, operator, investor]);
        const args = {
            price,
            amount,
            depositCids,
            pair: wrapDamlTuple(tokenPair)
        };

        await ledger.exerciseByKey(ExchangeParticipant.ExchangeParticipant_PlaceOffer, key, args);
    }

    return (
        <Page
            sideNav={sideNav}
            menuTitle={<><ExchangeIcon/>{base}/{quote}</>}
            onLogout={onLogout}
        >
            <PageSection border='blue' background='white'>
                <div className='investor-trade'>
                    <div className='order-forms'>
                        <OrderForm
                            quotePrecision={quotePrecision}
                            kind={OrderKind.BID}
                            placeOrder={placeBid}
                            assetPrecisions={[quotePrecision, basePrecision]}
                            labels={[quote, base]}
                            deposits={bidDeposits}/>

                        {/* <OrderForm
                            quotePrecision={quotePrecision}
                            kind={OrderKind.OFFER}
                            placeOrder={placeOffer}
                            assetPrecisions={[basePrecision, quotePrecision]}
                            labels={[base, quote]}
                            deposits={offerDeposits}/> */}
                    </div>
                    <OrderLadder orders={marketData}/>
                </div>
            </PageSection>
        </Page>
    )
}

export default InvestorTrade;
