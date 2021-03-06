import { useEffect, useRef } from 'react'

import { DepositInfo } from './damlTypes'


const vowels = ['a', 'e', 'i', 'o', 'u'];

export const indefiniteArticle = (word: string): string => {
    return vowels.includes(word[0].toLowerCase()) ? `an ${word}` : `a ${word}`;
}

export type StringKeyedObject<T> = {
    [key: string]: T
}

export const groupDeposits = (deposits: DepositInfo[], getLabel: (deposit: DepositInfo) => string): StringKeyedObject<DepositInfo[]> => {
    return deposits.reduce((group, deposit) => {
        const label = getLabel(deposit);
        const existingValue = group[label] || [];

        return { ...group, [label]: [...existingValue, deposit] };
    }, {} as StringKeyedObject<DepositInfo[]>);
}

export const groupDepositsByProvider = (deposits: DepositInfo[]): StringKeyedObject<DepositInfo[]> => {
    return groupDeposits(deposits, (deposit => deposit.contractData.account.provider))
}

export const groupDepositsByAsset = (deposits: DepositInfo[]): StringKeyedObject<DepositInfo[]> => {
    return groupDeposits(deposits, (deposit => deposit.contractData.asset.id.label))
}

export const sumDepositArray = (deposits: DepositInfo[]): number =>
    deposits.reduce((sum, val) => sum + Number(val.contractData.asset.quantity), 0);

export const sumDeposits = (deposits: DepositInfo[]): StringKeyedObject<number> => {
    const depositGroup = groupDepositsByAsset(deposits);

    return Object
        .entries(depositGroup)
        .reduce((acc, [label, deposits]) => ({
            ...acc,
            [label]: sumDepositArray(deposits)
        }), {} as StringKeyedObject<number>)
}

export const depositSummary = (deposits: DepositInfo[]): string => {
    const depositSums = sumDeposits(deposits);

    return Object
        .entries(depositSums)
        .map(([label, total]) => `${label}: ${total}`)
        .join(", ");
}

export function countDecimals(value: number) {
    if (Math.floor(value) !== value)
        return value.toString().split(".")[1].length || 0;
    return 0;
}

type PreciseInputSteps = {
    step: string;
    placeholder: string;
}

export function preciseInputSteps(precision: number): PreciseInputSteps {
    const step = precision > 0
      ? `0.${"0".repeat(precision-1)}1`
      : '1';

    const placeholder = precision > 0
      ? `0.${"0".repeat(precision)}`
      : '0';

    return { step, placeholder };
}

export interface IDismissable<T extends HTMLElement, C extends HTMLElement> {
    refDismissable: React.RefObject<T>;
    refControl: React.RefObject<C>;
}

export function useDismissableElement<T extends HTMLElement, C extends HTMLElement = HTMLElement>(
    onRequestClose: () => void): IDismissable<T, C>
{
    const refDismissable = useRef<T>(null);
    const refControl = useRef<C>(null);

    useEffect(() => {
        function checkForDismissClick(e: any) {
            const dismissable  = refDismissable.current;
            const control = refControl.current;

            if (!dismissable || dismissable.contains(e.target)) {
                return;
            }

            if (control && control.contains(e.target)) {
                return;
            }

            onRequestClose();
        }

        function checkForDismissKey(e: any) {
            if (e.key === 'Escape' || e.keyCode === 27) {
                onRequestClose();
            }
        }

        document.addEventListener("mousedown", checkForDismissClick);
        document.addEventListener("keydown", checkForDismissKey);
        return () => {
            document.removeEventListener("mousedown", checkForDismissClick);
            document.removeEventListener("keydown", checkForDismissKey);
        }
    }, [ onRequestClose ]);

    return { refDismissable, refControl };
}
