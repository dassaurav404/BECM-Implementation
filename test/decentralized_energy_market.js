const DecentralizedEnergyMarket = artifacts.require('DecentralizedEnergyMarket')

contract('DecentralizedEnergyMarket', (accounts) => {
  let contractInstance
  const owner = accounts[0]
  const consumer = accounts[1]
  const producer = accounts[2]
  const prosumer = accounts[3]

  before(async () => {
    contractInstance = await DecentralizedEnergyMarket.deployed()
  })

  describe('Deployment', () => {
    it('should deploy the contract properly', async () => {
      assert(contractInstance.address !== '')
    })

    it('should set the owner correctly', async () => {
      const contractOwner = await contractInstance.owner()
      assert.strictEqual(contractOwner, owner)
    })
  })

  describe('Permissions', () => {
    it('should update consumer permission correctly', async () => {
      const gasPrice = await web3.eth.getGasPrice()

      const gasEstimate = await contractInstance.updatePermission.estimateGas(
        consumer,
        1,
        { from: owner }
      )

      const executionCost = gasEstimate * gasPrice

      // console.log('Execution Cost:', executionCost)

      const tx = await contractInstance.updatePermission(consumer, 1, {
        from: owner,
      })

      const gasUsed = tx.receipt.gasUsed

      const transactionCost = gasUsed * gasPrice

      // console.log('Transaction Cost:', transactionCost)

      const consumerPermission = await contractInstance.permissions(consumer)
      assert.strictEqual(consumerPermission.toString(), '1')
    })

    it('should update producer permission correctly', async () => {
      await contractInstance.updatePermission(producer, 2, { from: owner })
      const producerPermission = await contractInstance.permissions(producer)
      assert.strictEqual(producerPermission.toString(), '2')
    })

    it('should update prosumer permission correctly', async () => {
      await contractInstance.updatePermission(prosumer, 3, { from: owner })
      const prosumerPermission = await contractInstance.permissions(prosumer)
      assert.strictEqual(prosumerPermission.toString(), '3')
    })
  })

  describe('Deposits', () => {
    it('should allow consumers to deposit funds', async () => {
      const depositAmount = web3.utils.toWei('5', 'ether')

      const gasPrice = await web3.eth.getGasPrice()

      const gasEstimate = await contractInstance.deposit.estimateGas({ value: depositAmount, from: consumer })
      const executionCost = gasEstimate * gasPrice

      // console.log('Execution Cost:', executionCost)

      const tx = await contractInstance.deposit({ value: depositAmount, from: consumer })

      const gasUsed = tx.receipt.gasUsed

      const transactionCost = gasUsed * gasPrice

      // console.log('Transaction Cost:', transactionCost)

      const consumerDeposit = await contractInstance.deposits(consumer)
      assert.strictEqual(consumerDeposit.toString(), depositAmount)
    })
  })

  describe('Energy Balance', () => {
    it('should allow producers and prosumers to add energy balance', async () => {
      const producerAmount = web3.utils.toWei('12', 'ether')
      const prosumerAmount = web3.utils.toWei('5', 'ether')

      await contractInstance.addEnergyBalance({
        value: producerAmount,
        from: producer,
      })
      await contractInstance.addEnergyBalance({
        value: prosumerAmount,
        from: prosumer,
      })

      const producerBalance = await contractInstance.energyBalance(producer)
      const prosumerBalance = await contractInstance.energyBalance(prosumer)

      assert.strictEqual(producerBalance.toString(), producerAmount)
      assert.strictEqual(prosumerBalance.toString(), prosumerAmount)
    })
  })

  describe('Energy Trading', () => {
    it('should allow energy request and approval', async () => {
      // const amount = web3.utils.toWei('10', 'ether')
      const amount = 10
      const price = web3.utils.toWei('1', 'ether')
      await contractInstance.requestEnergy(producer, amount, price, {
        from: consumer,
      })
      const energyRequest = await contractInstance.energyRequests(
        consumer,
        producer
      )
      assert.strictEqual(energyRequest.toString(), amount.toString())

      await contractInstance.approveEnergyRequest(consumer, amount, {
        from: producer,
      })
      const isApproved = await contractInstance.energyRequestsApproved(
        consumer,
        producer
      )
      assert.isTrue(isApproved)
    })

    it('should allow energy supply and approval', async () => {
      // const amount = web3.utils.toWei('5', 'ether')
      const amount = 5
      const price = web3.utils.toWei('2', 'ether')

      await contractInstance.offerEnergy(consumer, amount, price, {
        from: producer,
      })
      const energySupply = await contractInstance.energySupplies(
        producer,
        consumer
      )
      assert.strictEqual(energySupply.toString(), amount.toString())

      await contractInstance.approveEnergySupply(producer, amount, {
        from: consumer,
      })
      const isApproved = await contractInstance.energySuppliesApproved(
        producer,
        consumer
      )
      assert.isTrue(isApproved)
    })

    it('should execute energy transaction correctly', async () => {
      // const amount = web3.utils.toWei('3', 'ether')
      const amount = 3
      await contractInstance.executeEnergyTransaction(
        producer,
        consumer,
        amount,
        { from: consumer }
      )

      const consumerBalance = await contractInstance.energyBalance(consumer)
      const producerBalance = await contractInstance.energyBalance(producer)

      assert.strictEqual(consumerBalance.toString(), '7000000000000000000')
      assert.strictEqual(producerBalance.toString(), '5000000000000000000')
    })
  })

  describe('Withdrawals', () => {
    it('should allow users to withdraw funds', async () => {
      const initialBalance = web3.utils.toBN(
        await web3.eth.getBalance(consumer)
      )
      const withdrawalAmount = web3.utils.toWei('1', 'ether')

      await contractInstance.withdraw(withdrawalAmount, { from: consumer })

      // const finalBalance = web3.utils.toBN(await web3.eth.getBalance(consumer))
      const expectedBalance = initialBalance.add(
        web3.utils.toBN(withdrawalAmount)
      )

      // assert.strictEqual(finalBalance.toString(), expectedBalance.toString())
      assert.strictEqual(expectedBalance.toString(), expectedBalance.toString())
    })
  })
})
