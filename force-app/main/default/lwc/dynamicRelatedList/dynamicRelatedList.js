import { LightningElement, api, track, wire } from 'lwc';
import getRelatedListData from '@salesforce/apex/DynamicRelatedListController.getRelatedListData';

const DEFAULT_PAGE_SIZE = 10;
const DEFAULT_ICON = 'standard:record';

export default class DynamicRelatedList extends LightningElement {
    // ─── Public Properties (Design Attributes) ────────────────────────
    @api cardTitle = 'Related Records';
    @api iconName = '';
    @api bucketName = '';
    @api objectKey = '';
    @api region = 'us-east-1';
    @api authMode = 'named_credential'; // 'named_credential', 'presigned_url', 'direct'
    @api presignedUrl = '';
    @api accessKey = '';
    @api secretKey = '';
    @api fieldsList = '';
    @api sortByField = '';
    @api sortDirection = 'asc';
    @api recordLimit = 0;
    @api filterField = '';
    @api filterValue = '';
    @api pageSize = DEFAULT_PAGE_SIZE;
    @api hideCheckbox = true;
    @api showRowNumbers = false;
    @api showSearchBar = false;
    @api showRefreshButton = true;
    @api showViewAll = false;
    @api maxRowSelection = '10';
    @api disableColumnResize = false;
    @api emptyStateMessage = 'No records to display.';

    // ─── Tracked State ────────────────────────────────────────────────
    @track allRecords = [];
    @track tableColumns = [];
    @track objectLabel = '';
    @track objectApiName = '';
    @track s3IconName = '';
    @track totalCount = 0;
    @track errorMessage = '';
    @track searchTerm = '';
    @track sortedBy = '';
    @track sortedDirection = 'asc';
    @track currentPage = 1;
    @track isLoading = true;

    // ─── Private Properties ───────────────────────────────────────────
    _filteredRecords = [];
    _wiredResult;
    _rowActions = [
        { label: 'View', name: 'view' },
        { label: 'Edit', name: 'edit' }
    ];

    // ─── Wired Apex Call ──────────────────────────────────────────────
    @wire(getRelatedListData, {
        bucketName: '$bucketName',
        objectKey: '$objectKey',
        region: '$region',
        authMode: '$authMode',
        presignedUrl: '$presignedUrl',
        accessKey: '$accessKey',
        secretKey: '$secretKey',
        fieldsList: '$fieldsList',
        sortBy: '$sortByField',
        sortDirection: '$sortDirection',
        recordLimit: '$recordLimit',
        filterField: '$filterField',
        filterValue: '$filterValue'
    })
    wiredRelatedListData(result) {
        this._wiredResult = result;
        this.isLoading = false;

        if (result.data) {
            this.processResult(result.data);
            this.errorMessage = '';
        } else if (result.error) {
            this.handleError(result.error);
        }
    }

    // ─── Data Processing ──────────────────────────────────────────────
    processResult(data) {
        // Set metadata
        this.objectLabel = data.objectLabel || this.cardTitle;
        this.objectApiName = data.objectApiName || '';
        this.s3IconName = data.iconName || '';
        this.totalCount = data.totalCount || 0;

        // Build columns with row actions
        const cols = (data.columns || []).map(col => ({
            label: col.label,
            fieldName: col.fieldName,
            type: col.type || 'text',
            sortable: col.sortable !== false,
            typeAttributes: col.typeAttributes || undefined,
            cellAttributes: col.cellAttributes || undefined
        }));

        // Add row action column
        cols.push({
            type: 'action',
            typeAttributes: {
                rowActions: this._rowActions,
                menuAlignment: 'auto'
            }
        });

        this.tableColumns = cols;

        // Store records
        this.allRecords = data.records || [];
        this._filteredRecords = [...this.allRecords];
        this.currentPage = 1;

        // Apply initial sort
        if (this.sortByField) {
            this.sortedBy = this.sortByField;
            this.sortedDirection = this.sortDirection || 'asc';
        }
    }

    handleError(error) {
        if (error.body && error.body.message) {
            this.errorMessage = error.body.message;
        } else if (typeof error === 'string') {
            this.errorMessage = error;
        } else {
            this.errorMessage = 'An unexpected error occurred while loading data.';
        }
        this.allRecords = [];
        this._filteredRecords = [];
        this.tableColumns = [];
    }

    // ─── Computed Properties ──────────────────────────────────────────
    get resolvedIconName() {
        return this.iconName || this.s3IconName || DEFAULT_ICON;
    }

    get showCount() {
        return this.totalCount > 0;
    }

    get hasError() {
        return this.errorMessage && !this.isLoading;
    }

    get hasRecords() {
        return !this.isLoading && !this.hasError && this._filteredRecords.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.hasError && this._filteredRecords.length === 0;
    }

    get searchPlaceholder() {
        return `Search ${this.objectLabel || this.cardTitle}...`;
    }

    // ─── Pagination ───────────────────────────────────────────────────
    get totalPages() {
        const size = this._parsedPageSize;
        if (size <= 0 || this._filteredRecords.length === 0) return 1;
        return Math.ceil(this._filteredRecords.length / size);
    }

    get _parsedPageSize() {
        const size = parseInt(this.pageSize, 10);
        return isNaN(size) || size <= 0 ? DEFAULT_PAGE_SIZE : size;
    }

    get displayedRecords() {
        const size = this._parsedPageSize;
        const start = (this.currentPage - 1) * size;
        const end = start + size;
        return this._filteredRecords.slice(start, end);
    }

    get showPagination() {
        return this.hasRecords && this.totalPages > 1;
    }

    get isPrevDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    // ─── Event Handlers ───────────────────────────────────────────────
    handleRefresh() {
        this.isLoading = true;
        this.errorMessage = '';
        this.searchTerm = '';

        // Re-fetch by refreshing the wire
        if (this._wiredResult) {
            import('lightning/uiRecordApi').then(() => {
                // Force wire refresh by using refreshApex
            }).catch(() => {
                // Fallback: imperative call
                this.fetchDataImperative();
            });
        }

        // Imperative fetch as fallback
        this.fetchDataImperative();
    }

    fetchDataImperative() {
        getRelatedListData({
            bucketName: this.bucketName,
            objectKey: this.objectKey,
            region: this.region,
            authMode: this.authMode,
            presignedUrl: this.presignedUrl,
            accessKey: this.accessKey,
            secretKey: this.secretKey,
            fieldsList: this.fieldsList,
            sortBy: this.sortByField,
            sortDirection: this.sortDirection,
            recordLimit: this.recordLimit,
            filterField: this.filterField,
            filterValue: this.filterValue
        })
            .then(data => {
                this.processResult(data);
                this.errorMessage = '';
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSearch(event) {
        const term = event.target.value.toLowerCase().trim();
        this.searchTerm = term;

        if (!term) {
            this._filteredRecords = [...this.allRecords];
        } else {
            this._filteredRecords = this.allRecords.filter(record => {
                return Object.values(record).some(val => {
                    if (val == null) return false;
                    return String(val).toLowerCase().includes(term);
                });
            });
        }

        this.currentPage = 1;
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        const sorted = [...this._filteredRecords].sort((a, b) => {
            let valA = a[fieldName];
            let valB = b[fieldName];

            if (valA == null) valA = '';
            if (valB == null) valB = '';

            // Attempt numeric comparison
            const numA = Number(valA);
            const numB = Number(valB);
            if (!isNaN(numA) && !isNaN(numB)) {
                return sortDirection === 'asc' ? numA - numB : numB - numA;
            }

            // String comparison
            const strA = String(valA).toLowerCase();
            const strB = String(valB).toLowerCase();
            if (sortDirection === 'asc') {
                return strA < strB ? -1 : strA > strB ? 1 : 0;
            }
            return strA > strB ? -1 : strA < strB ? 1 : 0;
        });

        this._filteredRecords = sorted;
        this.currentPage = 1;
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    handleViewAll() {
        this.dispatchEvent(new CustomEvent('viewall', {
            detail: {
                objectApiName: this.objectApiName,
                objectLabel: this.objectLabel
            }
        }));
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        this.dispatchEvent(new CustomEvent('rowaction', {
            detail: {
                actionName: action.name,
                record: row
            }
        }));
    }
}
