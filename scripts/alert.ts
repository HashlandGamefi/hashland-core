import { constants } from 'ethers';
import { ethers } from 'hardhat';
import TelegramBot from 'node-telegram-bot-api';

const hcAddr = '0x20a3276972380E3c456137E49c32061498311Dd2';
const hclpAddr = '0xdb83d062fa300fb8b00f6ceb79ecc71dfef921a5';
const busdAddr = '0x6cbb3ef5a8c9743a1e2148d6dca69f3ba26bc8c5';
const pancakeRouterAddr = '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3';

const hclpAbi = [
  'event Mint(address indexed sender, uint amount0, uint amount1)',
  'event Burn(address indexed sender, uint amount0, uint amount1, address indexed to)',
  'event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to)',
  'event Sync(uint112 reserve0, uint112 reserve1)',
  'event Transfer(address indexed from, address indexed to, uint value)',
];
const pancakeRouterAbi = [
  'function getAmountsOut(uint amountIn, address[] memory path) public view virtual override returns (uint[] memory amounts)',
];

async function main() {
  const token = process.env.TOKEN as string;
  const bot = new TelegramBot(token, { polling: true });

  const hc = await ethers.getContractAt('HC', hcAddr);
  const hclp = await ethers.getContractAt(hclpAbi, hclpAddr);
  const pancakeRouter = await ethers.getContractAt(pancakeRouterAbi, pancakeRouterAddr);

  bot.onText(/\/lp/, async (msg, match) => {
    const totalSupply = await hclp.totalSupply();
    const chatId = msg.chat.id;
    const message = `HC LP Total Supply: ${(totalSupply / 1e18).toFixed(4)}`;
    console.log(message);
    bot.sendMessage(chatId, message);
  });

  hclp.on('Mint', (sender, hcAmount, busdAmount, event) => {
    const message = `[Add Liquidity] ${(hcAmount / 1e18).toFixed(4)} HC and ${(busdAmount / 1e18).toFixed(4)} BUSD have been added to the pool`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });

  hclp.on('Burn', (sender, hcAmount, busdAmount, to, event) => {
    const message = `[Remove Liquidity] Removed ${(hcAmount / 1e18).toFixed(4)} HC and ${(busdAmount / 1e18).toFixed(4)} BUSD from the pool`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });

  hclp.on('Swap', async (sender, hcAmountIn, busdAmountIn, hcAmountOut, busdAmountOunt, to, event) => {
    let message;
    if (hcAmountIn > 0 && busdAmountOunt > 0) {
      message = `[Sell HC] ${to} swap ${(hcAmountIn / 1e18).toFixed(4)} HC to ${(busdAmountOunt / 1e18).toFixed(4)} BUSD`;
    } else {
      message = `[Buy HC] ${to} swap ${(busdAmountIn / 1e18).toFixed(4)} BUSD to ${(hcAmountOut / 1e18).toFixed(4)} HC`;
    }
    console.log(message);
    bot.sendMessage(-670292888, message);

    const hcPrice = (await pancakeRouter.getAmountsOut(constants.WeiPerEther, [hcAddr, busdAddr]))[1];
    message = `[HC Info] HC current price is ${hcPrice} BUSD`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });

  hclp.on('Sync', (hcAmount, busdAmount, event) => {
    const message = `[Pool Info] The pool now has ${(hcAmount / 1e18).toFixed(4)} HC and ${(busdAmount / 1e18).toFixed(4)} BUSD`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });

  const filterMintLP = hclp.filters.Transfer('0x0000000000000000000000000000000000000000');
  hclp.on(filterMintLP, (from, to, amount, event) => {
    const message = `[Mint LP] ${to} got ${(amount / 1e18).toFixed(4)} LP`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });

  const filterBurnLP = hclp.filters.Transfer(null, hclpAddr);
  hclp.on(filterBurnLP, (from, to, amount, event) => {
    const message = `[Burn LP] ${from} lost ${(amount / 1e18).toFixed(4)} LP`;
    console.log(message);
    bot.sendMessage(-670292888, message);
  });
}

main();
